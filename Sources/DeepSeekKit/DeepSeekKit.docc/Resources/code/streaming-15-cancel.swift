import SwiftUI
import DeepSeekKit

// Adding the ability to stop streaming mid-response
struct CancellableStreamingView: View {
    @StateObject private var streamController = StreamCancellationController()
    @State private var prompt = ""
    @State private var showCancellationOptions = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Cancellable Streaming")
                .font(.largeTitle)
                .bold()
            
            // Stream control panel
            StreamControlPanel(controller: streamController)
            
            // Messages with cancellation states
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(streamController.messages) { message in
                        CancellableMessageView(message: message)
                    }
                    
                    if streamController.isStreaming {
                        ActiveStreamControls(controller: streamController)
                    }
                }
                .padding()
            }
            
            // Cancellation options
            if showCancellationOptions {
                CancellationOptionsView(
                    controller: streamController,
                    isShowing: $showCancellationOptions
                )
            }
            
            // Input with stream controls
            VStack(spacing: 12) {
                HStack {
                    TextField("Enter your message", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                        .disabled(streamController.isStreaming)
                    
                    if streamController.isStreaming {
                        Button(action: {
                            showCancellationOptions = true
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: {
                            Task {
                                await streamController.startStream(prompt)
                                prompt = ""
                            }
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .disabled(prompt.isEmpty)
                    }
                }
                
                // Quick action buttons
                if streamController.isStreaming {
                    HStack(spacing: 12) {
                        Button("Stop Now") {
                            streamController.cancelImmediately()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        
                        Button("Stop After Sentence") {
                            streamController.cancelAfterSentence()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Pause") {
                            streamController.pauseStream()
                        }
                        .buttonStyle(.bordered)
                        .disabled(streamController.isPaused)
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Stream cancellation controller
@MainActor
class StreamCancellationController: ObservableObject {
    @Published var messages: [CancellableMessage] = []
    @Published var isStreaming = false
    @Published var isPaused = false
    @Published var streamStats = StreamStats()
    @Published var cancellationPending = false
    
    private let client = DeepSeekClient()
    private var currentStreamTask: Task<Void, Never>?
    private var cancellationType: CancellationType = .immediate
    private var pausedContent = ""
    
    enum CancellationType {
        case immediate
        case afterSentence
        case afterParagraph
        case afterWord
        case graceful
    }
    
    struct CancellableMessage: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        var status: MessageStatus
        let timestamp = Date()
        var metadata: MessageMetadata
        
        enum MessageStatus {
            case complete
            case streaming
            case cancelled(at: Int, reason: String)
            case paused(at: Int)
            case resumed
        }
        
        struct MessageMetadata {
            var totalChunks: Int = 0
            var cancelledAtChunk: Int?
            var duration: TimeInterval?
            var wasPaused: Bool = false
            var resumeCount: Int = 0
        }
    }
    
    struct StreamStats {
        var totalStreams: Int = 0
        var completedStreams: Int = 0
        var cancelledStreams: Int = 0
        var averageCompletionRate: Double = 0
        var totalTokensSaved: Int = 0
    }
    
    func startStream(_ prompt: String) async {
        isStreaming = true
        isPaused = false
        cancellationPending = false
        streamStats.totalStreams += 1
        
        // Add user message
        let userMessage = CancellableMessage(
            role: "user",
            content: prompt,
            status: .complete,
            metadata: CancellableMessage.MessageMetadata()
        )
        messages.append(userMessage)
        
        // Create assistant message
        var assistantMessage = CancellableMessage(
            role: "assistant",
            content: "",
            status: .streaming,
            metadata: CancellableMessage.MessageMetadata()
        )
        let messageId = assistantMessage.id
        messages.append(assistantMessage)
        
        // Start cancellable stream
        currentStreamTask = Task {
            await performCancellableStream(messageId: messageId, prompt: prompt)
        }
        
        await currentStreamTask?.value
        isStreaming = false
    }
    
    private func performCancellableStream(messageId: UUID, prompt: String) async {
        let startTime = Date()
        var chunkCount = 0
        var shouldCancel = false
        
        do {
            for try await chunk in client.streamMessage(prompt) {
                // Check for immediate cancellation
                if Task.isCancelled || (cancellationType == .immediate && cancellationPending) {
                    shouldCancel = true
                    break
                }
                
                // Handle pause
                while isPaused && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
                
                // Process chunk
                if let content = chunk.choices.first?.delta.content {
                    chunkCount += 1
                    
                    // Check for graceful cancellation points
                    if cancellationPending {
                        shouldCancel = shouldCancelAt(
                            content: content,
                            currentContent: messages.first(where: { $0.id == messageId })?.content ?? ""
                        )
                        if shouldCancel { break }
                    }
                    
                    // Update message
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].content += content
                        messages[index].metadata.totalChunks = chunkCount
                    }
                }
                
                // Check for completion
                if chunk.choices.first?.finishReason != nil {
                    completeMessage(messageId: messageId, duration: Date().timeIntervalSince(startTime))
                    streamStats.completedStreams += 1
                    break
                }
            }
        } catch {
            print("Stream error: \(error)")
        }
        
        // Handle cancellation
        if shouldCancel || cancellationPending {
            cancelMessage(
                messageId: messageId,
                atChunk: chunkCount,
                duration: Date().timeIntervalSince(startTime)
            )
            streamStats.cancelledStreams += 1
        }
        
        updateCompletionRate()
        cancellationPending = false
    }
    
    private func shouldCancelAt(content: String, currentContent: String) -> Bool {
        let combined = currentContent + content
        
        switch cancellationType {
        case .immediate:
            return true
        case .afterSentence:
            return combined.last == "." || combined.last == "!" || combined.last == "?"
        case .afterParagraph:
            return content.contains("\n\n") || content.contains("\n")
        case .afterWord:
            return content.contains(" ") || content.last == " "
        case .graceful:
            // Cancel at natural breaking point
            return combined.hasSuffix(".") || combined.hasSuffix("\n")
        }
    }
    
    func cancelImmediately() {
        cancellationType = .immediate
        cancellationPending = true
        currentStreamTask?.cancel()
    }
    
    func cancelAfterSentence() {
        cancellationType = .afterSentence
        cancellationPending = true
    }
    
    func cancelAfterParagraph() {
        cancellationType = .afterParagraph
        cancellationPending = true
    }
    
    func cancelGracefully() {
        cancellationType = .graceful
        cancellationPending = true
    }
    
    func pauseStream() {
        isPaused = true
        if let index = messages.indices.last {
            let currentLength = messages[index].content.count
            messages[index].status = .paused(at: currentLength)
            messages[index].metadata.wasPaused = true
        }
    }
    
    func resumeStream() {
        isPaused = false
        if let index = messages.indices.last {
            messages[index].status = .resumed
            messages[index].metadata.resumeCount += 1
        }
    }
    
    private func cancelMessage(messageId: UUID, atChunk: Int, duration: TimeInterval) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            let reason = getCancellationReason()
            messages[index].status = .cancelled(
                at: messages[index].content.count,
                reason: reason
            )
            messages[index].metadata.cancelledAtChunk = atChunk
            messages[index].metadata.duration = duration
            
            // Estimate tokens saved
            let estimatedRemainingTokens = max(0, 200 - atChunk * 5) // Rough estimate
            streamStats.totalTokensSaved += estimatedRemainingTokens
        }
    }
    
    private func completeMessage(messageId: UUID, duration: TimeInterval) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .complete
            messages[index].metadata.duration = duration
        }
    }
    
    private func getCancellationReason() -> String {
        switch cancellationType {
        case .immediate:
            return "Stopped immediately"
        case .afterSentence:
            return "Stopped at sentence end"
        case .afterParagraph:
            return "Stopped at paragraph end"
        case .afterWord:
            return "Stopped at word boundary"
        case .graceful:
            return "Stopped gracefully"
        }
    }
    
    private func updateCompletionRate() {
        let total = streamStats.totalStreams
        let completed = streamStats.completedStreams
        streamStats.averageCompletionRate = total > 0 ? Double(completed) / Double(total) : 0
    }
}

// UI Components
struct StreamControlPanel: View {
    @ObservedObject var controller: StreamCancellationController
    
    var body: some View {
        VStack(spacing: 12) {
            // Stream status
            HStack {
                StatusIndicator(
                    isStreaming: controller.isStreaming,
                    isPaused: controller.isPaused,
                    cancellationPending: controller.cancellationPending
                )
                
                Spacer()
                
                if controller.isStreaming {
                    StreamTimer()
                }
            }
            
            // Statistics
            HStack(spacing: 20) {
                StatItem(
                    label: "Total",
                    value: "\(controller.streamStats.totalStreams)",
                    icon: "sum"
                )
                
                StatItem(
                    label: "Completed",
                    value: "\(controller.streamStats.completedStreams)",
                    icon: "checkmark.circle"
                )
                
                StatItem(
                    label: "Cancelled",
                    value: "\(controller.streamStats.cancelledStreams)",
                    icon: "xmark.circle"
                )
                
                StatItem(
                    label: "Tokens Saved",
                    value: "~\(controller.streamStats.totalTokensSaved)",
                    icon: "bolt.circle"
                )
            }
            .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatusIndicator: View {
    let isStreaming: Bool
    let isPaused: Bool
    let cancellationPending: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isStreaming && !isPaused ? 1.5 : 1)
                        .opacity(isStreaming && !isPaused ? 0 : 1)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: isStreaming)
                )
            
            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if cancellationPending {
                Text("(Cancelling...)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    var statusColor: Color {
        if cancellationPending { return .orange }
        if isPaused { return .yellow }
        if isStreaming { return .green }
        return .gray
    }
    
    var statusText: String {
        if isPaused { return "Paused" }
        if isStreaming { return "Streaming" }
        return "Idle"
    }
}

struct ActiveStreamControls: View {
    @ObservedObject var controller: StreamCancellationController
    
    var body: some View {
        VStack(spacing: 16) {
            // Visual stream progress
            StreamProgressView()
            
            // Control buttons
            HStack(spacing: 12) {
                if controller.isPaused {
                    Button(action: { controller.resumeStream() }) {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: { controller.pauseStream() }) {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                }
                
                Menu {
                    Button("Stop Immediately", role: .destructive) {
                        controller.cancelImmediately()
                    }
                    
                    Button("Stop After Sentence") {
                        controller.cancelAfterSentence()
                    }
                    
                    Button("Stop After Paragraph") {
                        controller.cancelAfterParagraph()
                    }
                    
                    Button("Stop Gracefully") {
                        controller.cancelGracefully()
                    }
                } label: {
                    Label("Stop Options", systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
}

struct CancellableMessageView: View {
    let message: StreamCancellationController.CancellableMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(message.role.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                MessageStatusBadge(status: message.status)
            }
            
            // Content
            Text(message.content)
                .padding()
                .background(backgroundForStatus)
                .cornerRadius(10)
            
            // Cancellation info
            if case .cancelled(let position, let reason) = message.status {
                CancellationInfoView(
                    position: position,
                    reason: reason,
                    metadata: message.metadata
                )
            }
            
            // Metadata
            if message.metadata.totalChunks > 0 {
                MessageMetadataView(metadata: message.metadata)
            }
        }
    }
    
    var backgroundForStatus: Color {
        switch message.status {
        case .complete:
            return Color.gray.opacity(0.1)
        case .streaming:
            return Color.blue.opacity(0.05)
        case .cancelled:
            return Color.red.opacity(0.05)
        case .paused:
            return Color.yellow.opacity(0.05)
        case .resumed:
            return Color.green.opacity(0.05)
        }
    }
}

struct MessageStatusBadge: View {
    let status: StreamCancellationController.CancellableMessage.MessageStatus
    
    var body: some View {
        Group {
            switch status {
            case .complete:
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .streaming:
                Label("Streaming", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundColor(.blue)
            case .cancelled:
                Label("Cancelled", systemImage: "stop.circle.fill")
                    .foregroundColor(.red)
            case .paused:
                Label("Paused", systemImage: "pause.circle.fill")
                    .foregroundColor(.yellow)
            case .resumed:
                Label("Resumed", systemImage: "play.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .font(.caption2)
    }
}

struct CancellationInfoView: View {
    let position: Int
    let reason: String
    let metadata: StreamCancellationController.CancellableMessage.MessageMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(reason, systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.red)
            
            HStack(spacing: 16) {
                Text("Stopped at character \(position)")
                
                if let chunk = metadata.cancelledAtChunk {
                    Text("Chunk \(chunk) of \(metadata.totalChunks)")
                }
                
                if let duration = metadata.duration {
                    Text("\(String(format: "%.1f", duration))s")
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

struct MessageMetadataView: View {
    let metadata: StreamCancellationController.CancellableMessage.MessageMetadata
    
    var body: some View {
        HStack(spacing: 16) {
            Label("\(metadata.totalChunks) chunks", systemImage: "square.stack")
            
            if metadata.wasPaused {
                Label("Paused \(metadata.resumeCount)x", systemImage: "pause")
            }
            
            if let duration = metadata.duration {
                Label("\(String(format: "%.1f", duration))s", systemImage: "timer")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal)
    }
}

struct CancellationOptionsView: View {
    @ObservedObject var controller: StreamCancellationController
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose how to stop the stream:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                CancellationOption(
                    title: "Stop Immediately",
                    description: "Stops the stream right away",
                    icon: "stop.fill",
                    color: .red,
                    action: {
                        controller.cancelImmediately()
                        isShowing = false
                    }
                )
                
                CancellationOption(
                    title: "Stop After Sentence",
                    description: "Completes the current sentence",
                    icon: "text.badge.checkmark",
                    color: .orange,
                    action: {
                        controller.cancelAfterSentence()
                        isShowing = false
                    }
                )
                
                CancellationOption(
                    title: "Stop After Paragraph",
                    description: "Finishes the current paragraph",
                    icon: "text.alignleft",
                    color: .blue,
                    action: {
                        controller.cancelAfterParagraph()
                        isShowing = false
                    }
                )
                
                CancellationOption(
                    title: "Stop Gracefully",
                    description: "Finds a natural stopping point",
                    icon: "hand.raised",
                    color: .green,
                    action: {
                        controller.cancelGracefully()
                        isShowing = false
                    }
                )
            }
            
            Button("Continue Streaming") {
                isShowing = false
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }
}

struct CancellationOption: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// Helper Views
struct StreamTimer: View {
    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeString)
            .font(.system(.caption, design: .monospaced))
            .onReceive(timer) { _ in
                elapsed += 0.1
            }
    }
    
    var timeString: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let tenths = Int((elapsed * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

struct StreamProgressView: View {
    @State private var progress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.blue, .blue.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * progress)
                    .animation(.linear(duration: 0.5), value: progress)
            }
        }
        .frame(height: 4)
        .cornerRadius(2)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}