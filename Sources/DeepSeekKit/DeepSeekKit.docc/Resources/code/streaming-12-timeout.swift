import SwiftUI
import DeepSeekKit

// Adding timeout handling for slow streams
struct StreamTimeoutView: View {
    @StateObject private var timeoutManager = StreamTimeoutManager()
    @State private var prompt = ""
    @State private var customTimeout: TimeInterval = 30
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Stream Timeout Handling")
                .font(.largeTitle)
                .bold()
            
            // Timeout configuration
            TimeoutConfigurationView(
                timeout: $customTimeout,
                manager: timeoutManager
            )
            
            // Active timers display
            if timeoutManager.isStreaming {
                ActiveTimersView(manager: timeoutManager)
            }
            
            // Messages
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(timeoutManager.messages) { message in
                        TimeoutAwareMessageView(message: message)
                    }
                }
                .padding()
            }
            
            // Timeout recovery options
            if let timeout = timeoutManager.lastTimeout {
                TimeoutRecoveryView(timeout: timeout, manager: timeoutManager)
            }
            
            // Input
            HStack {
                TextField("Enter prompt", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                
                Button("Send") {
                    Task {
                        await timeoutManager.streamWithTimeout(
                            prompt: prompt,
                            timeout: customTimeout
                        )
                        prompt = ""
                    }
                }
                .disabled(prompt.isEmpty || timeoutManager.isStreaming)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Stream timeout manager
@MainActor
class StreamTimeoutManager: ObservableObject {
    @Published var messages: [TimedMessage] = []
    @Published var isStreaming = false
    @Published var activeTimers: [TimerInfo] = []
    @Published var lastTimeout: TimeoutInfo?
    
    private let client = DeepSeekClient()
    private var streamTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var chunkTimeoutTask: Task<Void, Never>?
    
    struct TimedMessage: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        var timing: MessageTiming
        var status: MessageStatus
        
        struct MessageTiming {
            let startTime: Date
            var firstChunkTime: Date?
            var lastChunkTime: Date?
            var endTime: Date?
            var chunkIntervals: [TimeInterval] = []
            var totalChunks = 0
            var timeoutOccurred = false
            var timeoutType: TimeoutType?
            
            enum TimeoutType {
                case overall(duration: TimeInterval)
                case firstChunk(duration: TimeInterval)
                case betweenChunks(duration: TimeInterval)
            }
            
            var averageChunkInterval: TimeInterval? {
                guard !chunkIntervals.isEmpty else { return nil }
                return chunkIntervals.reduce(0, +) / Double(chunkIntervals.count)
            }
            
            var totalDuration: TimeInterval? {
                guard let end = endTime else { return nil }
                return end.timeIntervalSince(startTime)
            }
        }
        
        enum MessageStatus {
            case streaming
            case complete
            case timedOut(reason: String)
            case cancelled
        }
    }
    
    struct TimerInfo: Identifiable {
        let id = UUID()
        let type: TimerType
        let duration: TimeInterval
        let startTime: Date
        var elapsed: TimeInterval = 0
        var isActive = true
        
        enum TimerType {
            case overall
            case firstChunk
            case chunkInterval
        }
        
        var progress: Double {
            min(elapsed / duration, 1.0)
        }
        
        var remaining: TimeInterval {
            max(duration - elapsed, 0)
        }
    }
    
    struct TimeoutInfo {
        let messageId: UUID
        let type: TimedMessage.MessageTiming.TimeoutType
        let partialContent: String
        let timestamp: Date
        let canExtend: Bool
        let canRetry: Bool
    }
    
    func streamWithTimeout(
        prompt: String,
        timeout: TimeInterval,
        firstChunkTimeout: TimeInterval = 10,
        chunkTimeout: TimeInterval = 5
    ) async {
        // Add user message
        messages.append(TimedMessage(
            role: "user",
            content: prompt,
            timing: TimedMessage.MessageTiming(startTime: Date()),
            status: .complete
        ))
        
        // Create assistant message
        var assistantMessage = TimedMessage(
            role: "assistant",
            content: "",
            timing: TimedMessage.MessageTiming(startTime: Date()),
            status: .streaming
        )
        messages.append(assistantMessage)
        
        isStreaming = true
        lastTimeout = nil
        
        // Start timers
        startTimers(
            messageId: assistantMessage.id,
            overallTimeout: timeout,
            firstChunkTimeout: firstChunkTimeout,
            chunkTimeout: chunkTimeout
        )
        
        // Start streaming
        streamTask = Task {
            await performTimedStream(
                messageId: assistantMessage.id,
                prompt: prompt,
                chunkTimeout: chunkTimeout
            )
        }
        
        await streamTask?.value
        isStreaming = false
        clearTimers()
    }
    
    private func startTimers(
        messageId: UUID,
        overallTimeout: TimeInterval,
        firstChunkTimeout: TimeInterval,
        chunkTimeout: TimeInterval
    ) {
        // Overall timeout
        let overallTimer = TimerInfo(
            type: .overall,
            duration: overallTimeout,
            startTime: Date()
        )
        activeTimers.append(overallTimer)
        
        timeoutTask = Task {
            await monitorOverallTimeout(
                messageId: messageId,
                timeout: overallTimeout,
                timerId: overallTimer.id
            )
        }
        
        // First chunk timeout
        let firstChunkTimer = TimerInfo(
            type: .firstChunk,
            duration: firstChunkTimeout,
            startTime: Date()
        )
        activeTimers.append(firstChunkTimer)
        
        chunkTimeoutTask = Task {
            await monitorFirstChunkTimeout(
                messageId: messageId,
                timeout: firstChunkTimeout,
                timerId: firstChunkTimer.id
            )
        }
        
        // Update timer displays
        Task {
            while isStreaming {
                updateTimerProgress()
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
    }
    
    private func performTimedStream(
        messageId: UUID,
        prompt: String,
        chunkTimeout: TimeInterval
    ) async {
        var lastChunkTime = Date()
        var chunkCount = 0
        
        do {
            for try await chunk in client.streamMessage(prompt) {
                let now = Date()
                
                // Cancel if task is cancelled
                if Task.isCancelled { break }
                
                // Process chunk
                if let content = chunk.choices.first?.delta.content {
                    chunkCount += 1
                    
                    // Update message
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].content += content
                        messages[index].timing.totalChunks = chunkCount
                        
                        // Record timing
                        if chunkCount == 1 {
                            messages[index].timing.firstChunkTime = now
                            cancelFirstChunkTimeout()
                        }
                        
                        let interval = now.timeIntervalSince(lastChunkTime)
                        messages[index].timing.chunkIntervals.append(interval)
                        messages[index].timing.lastChunkTime = now
                        
                        lastChunkTime = now
                    }
                    
                    // Reset chunk interval timer
                    resetChunkIntervalTimeout(chunkTimeout: chunkTimeout)
                }
                
                // Check for completion
                if chunk.choices.first?.finishReason != nil {
                    completeMessage(messageId: messageId)
                    break
                }
            }
        } catch {
            handleStreamError(messageId: messageId, error: error)
        }
    }
    
    private func monitorOverallTimeout(
        messageId: UUID,
        timeout: TimeInterval,
        timerId: UUID
    ) async {
        do {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            
            if isStreaming {
                handleTimeout(
                    messageId: messageId,
                    type: .overall(duration: timeout),
                    reason: "Stream exceeded overall timeout of \(Int(timeout))s"
                )
            }
        } catch {
            // Task cancelled
        }
        
        deactivateTimer(timerId: timerId)
    }
    
    private func monitorFirstChunkTimeout(
        messageId: UUID,
        timeout: TimeInterval,
        timerId: UUID
    ) async {
        do {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            
            if isStreaming,
               let message = messages.first(where: { $0.id == messageId }),
               message.timing.firstChunkTime == nil {
                handleTimeout(
                    messageId: messageId,
                    type: .firstChunk(duration: timeout),
                    reason: "No response received within \(Int(timeout))s"
                )
            }
        } catch {
            // Task cancelled
        }
        
        deactivateTimer(timerId: timerId)
    }
    
    private func handleTimeout(
        messageId: UUID,
        type: TimedMessage.MessageTiming.TimeoutType,
        reason: String
    ) {
        // Cancel streaming
        streamTask?.cancel()
        
        // Update message
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .timedOut(reason: reason)
            messages[index].timing.timeoutOccurred = true
            messages[index].timing.timeoutType = type
            messages[index].timing.endTime = Date()
            
            // Store timeout info
            lastTimeout = TimeoutInfo(
                messageId: messageId,
                type: type,
                partialContent: messages[index].content,
                timestamp: Date(),
                canExtend: messages[index].content.count > 0,
                canRetry: true
            )
        }
        
        isStreaming = false
        clearTimers()
    }
    
    func extendTimeout(additionalTime: TimeInterval) {
        guard let timeout = lastTimeout else { return }
        
        // Clear last timeout
        lastTimeout = nil
        
        // Resume streaming with extended timeout
        if let message = messages.first(where: { $0.id == timeout.messageId }) {
            Task {
                await continueStream(
                    from: message,
                    additionalTimeout: additionalTime
                )
            }
        }
    }
    
    func retryAfterTimeout() {
        guard let timeout = lastTimeout else { return }
        
        if let message = messages.first(where: { $0.id == timeout.messageId }) {
            let retryPrompt = timeout.partialContent.isEmpty
                ? message.content
                : "Continue from: '\(timeout.partialContent.suffix(50))'"
            
            Task {
                await streamWithTimeout(prompt: retryPrompt, timeout: 60)
            }
        }
    }
    
    private func continueStream(from message: TimedMessage, additionalTimeout: TimeInterval) async {
        // Implementation for continuing a timed-out stream
        // This would reconnect and continue from where it left off
    }
    
    private func completeMessage(messageId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .complete
            messages[index].timing.endTime = Date()
        }
    }
    
    private func handleStreamError(messageId: UUID, error: Error) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .timedOut(reason: error.localizedDescription)
            messages[index].timing.endTime = Date()
        }
    }
    
    private func cancelFirstChunkTimeout() {
        chunkTimeoutTask?.cancel()
        if let index = activeTimers.firstIndex(where: { $0.type == .firstChunk }) {
            activeTimers[index].isActive = false
        }
    }
    
    private func resetChunkIntervalTimeout(chunkTimeout: TimeInterval) {
        // Reset chunk interval monitoring
        // This would track time between chunks
    }
    
    private func updateTimerProgress() {
        let now = Date()
        for index in activeTimers.indices {
            activeTimers[index].elapsed = now.timeIntervalSince(activeTimers[index].startTime)
        }
    }
    
    private func deactivateTimer(timerId: UUID) {
        if let index = activeTimers.firstIndex(where: { $0.id == timerId }) {
            activeTimers[index].isActive = false
        }
    }
    
    private func clearTimers() {
        timeoutTask?.cancel()
        chunkTimeoutTask?.cancel()
        activeTimers.removeAll()
    }
}

// UI Components
struct TimeoutConfigurationView: View {
    @Binding var timeout: TimeInterval
    @ObservedObject var manager: StreamTimeoutManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeout Configuration")
                .font(.headline)
            
            HStack {
                Text("Overall timeout:")
                Slider(value: $timeout, in: 10...120, step: 5)
                Text("\(Int(timeout))s")
                    .monospacedDigit()
                    .frame(width: 40)
            }
            
            HStack {
                Label("Smart timeouts enabled", systemImage: "brain")
                    .font(.caption)
                Spacer()
                Text("First chunk: 10s • Between chunks: 5s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ActiveTimersView: View {
    @ObservedObject var manager: StreamTimeoutManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Timers")
                .font(.headline)
            
            ForEach(manager.activeTimers.filter { $0.isActive }) { timer in
                TimerProgressView(timer: timer)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TimerProgressView: View {
    let timer: StreamTimeoutManager.TimerInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(timerLabel, systemImage: timerIcon)
                    .font(.caption)
                Spacer()
                Text("\(Int(timer.remaining))s")
                    .font(.caption)
                    .monospacedDigit()
            }
            
            ProgressView(value: timer.progress)
                .tint(progressColor)
        }
    }
    
    var timerLabel: String {
        switch timer.type {
        case .overall: return "Overall"
        case .firstChunk: return "First Chunk"
        case .chunkInterval: return "Chunk Interval"
        }
    }
    
    var timerIcon: String {
        switch timer.type {
        case .overall: return "timer"
        case .firstChunk: return "timer.circle"
        case .chunkInterval: return "timer.square"
        }
    }
    
    var progressColor: Color {
        if timer.progress > 0.8 {
            return .red
        } else if timer.progress > 0.6 {
            return .orange
        } else {
            return .blue
        }
    }
}

struct TimeoutAwareMessageView: View {
    let message: StreamTimeoutManager.TimedMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(message.role.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                MessageTimingBadge(timing: message.timing, status: message.status)
            }
            
            // Content
            Text(message.content.isEmpty ? "Waiting for response..." : message.content)
                .padding()
                .background(backgroundForStatus)
                .cornerRadius(10)
            
            // Timing details
            if message.role == "assistant" {
                TimingDetailsView(timing: message.timing)
            }
        }
    }
    
    var backgroundForStatus: Color {
        switch message.status {
        case .complete:
            return Color.gray.opacity(0.1)
        case .timedOut:
            return Color.red.opacity(0.05)
        case .streaming:
            return Color.blue.opacity(0.05)
        case .cancelled:
            return Color.orange.opacity(0.05)
        }
    }
}

struct MessageTimingBadge: View {
    let timing: StreamTimeoutManager.TimedMessage.MessageTiming
    let status: StreamTimeoutManager.TimedMessage.MessageStatus
    
    var body: some View {
        Group {
            switch status {
            case .streaming:
                Label("Streaming", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundColor(.blue)
            case .complete:
                if let duration = timing.totalDuration {
                    Label("\(String(format: "%.1f", duration))s", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                }
            case .timedOut(let reason):
                Label("Timeout", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            case .cancelled:
                Label("Cancelled", systemImage: "xmark.circle")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption2)
    }
}

struct TimingDetailsView: View {
    let timing: StreamTimeoutManager.TimedMessage.MessageTiming
    
    var body: some View {
        HStack(spacing: 16) {
            if let firstChunk = timing.firstChunkTime {
                let delay = firstChunk.timeIntervalSince(timing.startTime)
                Label("\(String(format: "%.1f", delay))s to first", systemImage: "clock.arrow.circlepath")
            }
            
            if let avgInterval = timing.averageChunkInterval {
                Label("\(String(format: "%.1f", avgInterval))s avg", systemImage: "metronome")
            }
            
            Label("\(timing.totalChunks) chunks", systemImage: "square.stack")
            
            if timing.timeoutOccurred, let type = timing.timeoutType {
                switch type {
                case .overall(let duration):
                    Label("Overall \(Int(duration))s", systemImage: "hourglass")
                        .foregroundColor(.red)
                case .firstChunk(let duration):
                    Label("First \(Int(duration))s", systemImage: "hourglass.tophalf.filled")
                        .foregroundColor(.orange)
                case .betweenChunks(let duration):
                    Label("Chunk \(Int(duration))s", systemImage: "hourglass.bottomhalf.filled")
                        .foregroundColor(.orange)
                }
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}

struct TimeoutRecoveryView: View {
    let timeout: StreamTimeoutManager.TimeoutInfo
    @ObservedObject var manager: StreamTimeoutManager
    @State private var additionalTime: TimeInterval = 30
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stream Timed Out", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text(timeoutDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if timeout.canExtend {
                HStack {
                    Text("Extend by:")
                    Slider(value: $additionalTime, in: 10...60, step: 5)
                    Text("\(Int(additionalTime))s")
                        .frame(width: 40)
                }
            }
            
            HStack {
                if timeout.canExtend {
                    Button("Extend & Continue") {
                        manager.extendTimeout(additionalTime: additionalTime)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if timeout.canRetry {
                    Button("Retry") {
                        manager.retryAfterTimeout()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Dismiss") {
                    manager.lastTimeout = nil
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    var timeoutDescription: String {
        switch timeout.type {
        case .overall(let duration):
            return "The stream exceeded the overall timeout of \(Int(duration)) seconds."
        case .firstChunk(let duration):
            return "No response was received within \(Int(duration)) seconds."
        case .betweenChunks(let duration):
            return "No new content received for \(Int(duration)) seconds."
        }
    }
}