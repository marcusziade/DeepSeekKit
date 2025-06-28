import SwiftUI
import DeepSeekKit

// Handling timeout errors with custom durations
struct TimeoutHandlingView: View {
    @StateObject private var timeoutManager = TimeoutManager()
    @State private var customTimeout: TimeInterval = 30
    @State private var testPrompt = "Generate a detailed explanation of quantum computing"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Timeout Error Handling")
                    .font(.largeTitle)
                    .bold()
                
                // Timeout configuration
                TimeoutConfigurationView(
                    customTimeout: $customTimeout,
                    manager: timeoutManager
                )
                
                // Active request monitor
                if timeoutManager.hasActiveRequest {
                    ActiveRequestMonitor(manager: timeoutManager)
                }
                
                // Timeout strategies
                TimeoutStrategiesView(manager: timeoutManager)
                
                // Test controls
                TimeoutTestControls(
                    manager: timeoutManager,
                    customTimeout: customTimeout,
                    testPrompt: $testPrompt
                )
                
                // Timeout history
                TimeoutHistoryView(history: timeoutManager.timeoutHistory)
                
                // Best practices
                TimeoutBestPracticesView()
            }
            .padding()
        }
    }
}

// Timeout manager
@MainActor
class TimeoutManager: ObservableObject {
    @Published var hasActiveRequest = false
    @Published var currentRequest: ActiveRequest?
    @Published var timeoutHistory: [TimeoutEvent] = []
    @Published var strategy: TimeoutStrategy = .adaptive
    @Published var stats = TimeoutStats()
    
    private let client = DeepSeekClient()
    private var requestTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    
    enum TimeoutStrategy: String, CaseIterable {
        case fixed = "Fixed Timeout"
        case adaptive = "Adaptive"
        case progressive = "Progressive"
        case operationBased = "Operation-Based"
        
        func calculateTimeout(
            for operation: OperationType,
            baseTimeout: TimeInterval,
            attempt: Int = 1
        ) -> TimeInterval {
            switch self {
            case .fixed:
                return baseTimeout
                
            case .adaptive:
                // Adjust based on operation complexity
                let multiplier = operation.complexityMultiplier
                return baseTimeout * multiplier
                
            case .progressive:
                // Increase timeout with each retry
                return baseTimeout * Double(attempt)
                
            case .operationBased:
                // Different timeouts for different operations
                return operation.recommendedTimeout
            }
        }
    }
    
    enum OperationType: String, CaseIterable {
        case simple = "Simple Query"
        case moderate = "Moderate Task"
        case complex = "Complex Generation"
        case streaming = "Streaming Response"
        
        var complexityMultiplier: Double {
            switch self {
            case .simple: return 0.5
            case .moderate: return 1.0
            case .complex: return 2.0
            case .streaming: return 3.0
            }
        }
        
        var recommendedTimeout: TimeInterval {
            switch self {
            case .simple: return 15
            case .moderate: return 30
            case .complex: return 60
            case .streaming: return 120
            }
        }
        
        var description: String {
            switch self {
            case .simple: return "Quick responses, < 100 tokens"
            case .moderate: return "Standard requests, 100-500 tokens"
            case .complex: return "Long-form content, > 500 tokens"
            case .streaming: return "Real-time streaming responses"
            }
        }
    }
    
    struct ActiveRequest: Identifiable {
        let id = UUID()
        let prompt: String
        let startTime = Date()
        var elapsedTime: TimeInterval = 0
        let timeout: TimeInterval
        let operation: OperationType
        var status: Status = .running
        
        enum Status {
            case running
            case completed
            case timedOut
            case cancelled
        }
        
        var remainingTime: TimeInterval {
            max(0, timeout - elapsedTime)
        }
        
        var progress: Double {
            min(elapsedTime / timeout, 1.0)
        }
    }
    
    struct TimeoutEvent: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let operation: OperationType
        let requestedTimeout: TimeInterval
        let actualDuration: TimeInterval
        let result: Result
        let prompt: String
        
        enum Result {
            case success
            case timeout
            case cancelled
            case error(String)
        }
    }
    
    struct TimeoutStats {
        var totalRequests = 0
        var successfulRequests = 0
        var timedOutRequests = 0
        var averageResponseTime: TimeInterval = 0
        var recommendedTimeout: TimeInterval = 30
        
        var timeoutRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(timedOutRequests) / Double(totalRequests)
        }
        
        mutating func updateRecommendation(basedOn history: [TimeoutEvent]) {
            let successfulTimes = history
                .filter { if case .success = $0.result { return true } else { return false } }
                .map { $0.actualDuration }
            
            guard !successfulTimes.isEmpty else { return }
            
            // Calculate 95th percentile
            let sorted = successfulTimes.sorted()
            let index = Int(Double(sorted.count) * 0.95)
            recommendedTimeout = sorted[min(index, sorted.count - 1)] * 1.2 // Add 20% buffer
        }
    }
    
    func sendRequest(
        prompt: String,
        timeout: TimeInterval,
        operation: OperationType
    ) async {
        hasActiveRequest = true
        stats.totalRequests += 1
        
        let request = ActiveRequest(
            prompt: prompt,
            timeout: timeout,
            operation: operation
        )
        currentRequest = request
        
        // Start elapsed time timer
        startElapsedTimer()
        
        // Create timeout task
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            
            if !Task.isCancelled && self.hasActiveRequest {
                await self.handleTimeout()
            }
        }
        
        // Create request task
        requestTask = Task {
            await performRequest(request: request)
        }
        
        await requestTask?.value
        
        // Cleanup
        timeoutTask?.cancel()
        hasActiveRequest = false
        currentRequest = nil
    }
    
    private func performRequest(request: ActiveRequest) async {
        let startTime = Date()
        
        do {
            // Configure request with timeout
            let response = try await withThrowingTaskGroup(of: ChatCompletionResponse.self) { group in
                group.addTask {
                    try await self.client.sendMessage(request.prompt)
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(request.timeout * 1_000_000_000))
                    throw URLError(.timedOut)
                }
                
                guard let result = try await group.next() else {
                    throw URLError(.unknown)
                }
                
                group.cancelAll()
                return result
            }
            
            // Success
            let duration = Date().timeIntervalSince(startTime)
            handleSuccess(request: request, duration: duration)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            if (error as? URLError)?.code == .timedOut {
                handleTimeout(duration: duration)
            } else {
                handleError(request: request, error: error, duration: duration)
            }
        }
    }
    
    private func handleSuccess(request: ActiveRequest, duration: TimeInterval) {
        stats.successfulRequests += 1
        updateAverageResponseTime(duration)
        
        let event = TimeoutEvent(
            operation: request.operation,
            requestedTimeout: request.timeout,
            actualDuration: duration,
            result: .success,
            prompt: request.prompt
        )
        
        timeoutHistory.insert(event, at: 0)
        stats.updateRecommendation(basedOn: timeoutHistory)
    }
    
    private func handleTimeout(duration: TimeInterval? = nil) async {
        guard let request = currentRequest else { return }
        
        stats.timedOutRequests += 1
        
        let event = TimeoutEvent(
            operation: request.operation,
            requestedTimeout: request.timeout,
            actualDuration: duration ?? request.timeout,
            result: .timeout,
            prompt: request.prompt
        )
        
        timeoutHistory.insert(event, at: 0)
        
        // Cancel the actual request
        requestTask?.cancel()
    }
    
    private func handleError(request: ActiveRequest, error: Error, duration: TimeInterval) {
        let event = TimeoutEvent(
            operation: request.operation,
            requestedTimeout: request.timeout,
            actualDuration: duration,
            result: .error(error.localizedDescription),
            prompt: request.prompt
        )
        
        timeoutHistory.insert(event, at: 0)
    }
    
    private func startElapsedTimer() {
        Task {
            while hasActiveRequest {
                if var request = currentRequest {
                    request.elapsedTime = Date().timeIntervalSince(request.startTime)
                    currentRequest = request
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
    }
    
    private func updateAverageResponseTime(_ newTime: TimeInterval) {
        let currentAvg = stats.averageResponseTime
        let totalRequests = Double(stats.successfulRequests)
        
        stats.averageResponseTime = ((currentAvg * (totalRequests - 1)) + newTime) / totalRequests
    }
    
    func cancelCurrentRequest() {
        requestTask?.cancel()
        timeoutTask?.cancel()
        
        if let request = currentRequest {
            let event = TimeoutEvent(
                operation: request.operation,
                requestedTimeout: request.timeout,
                actualDuration: request.elapsedTime,
                result: .cancelled,
                prompt: request.prompt
            )
            
            timeoutHistory.insert(event, at: 0)
        }
        
        hasActiveRequest = false
        currentRequest = nil
    }
}

// UI Components
struct TimeoutConfigurationView: View {
    @Binding var customTimeout: TimeInterval
    @ObservedObject var manager: TimeoutManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeout Configuration")
                .font(.headline)
            
            // Timeout slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Custom Timeout:")
                    Slider(value: $customTimeout, in: 5...120, step: 5)
                    Text("\(Int(customTimeout))s")
                        .frame(width: 40)
                        .monospacedDigit()
                }
                
                // Recommended timeout
                if manager.stats.totalRequests > 0 {
                    Label(
                        "Recommended: \(Int(manager.stats.recommendedTimeout))s",
                        systemImage: "lightbulb"
                    )
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Strategy picker
            Picker("Strategy", selection: $manager.strategy) {
                ForEach(TimeoutManager.TimeoutStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.rawValue).tag(strategy)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Strategy description
            Text(strategyDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var strategyDescription: String {
        switch manager.strategy {
        case .fixed:
            return "Always use the same timeout duration"
        case .adaptive:
            return "Adjust timeout based on request complexity"
        case .progressive:
            return "Increase timeout with each retry attempt"
        case .operationBased:
            return "Use predefined timeouts for different operations"
        }
    }
}

struct ActiveRequestMonitor: View {
    @ObservedObject var manager: TimeoutManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Request")
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel", role: .destructive) {
                    manager.cancelCurrentRequest()
                }
                .buttonStyle(.bordered)
            }
            
            if let request = manager.currentRequest {
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Operation: \(request.operation.rawValue)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(Int(request.remainingTime))s remaining")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    
                    ProgressView(value: request.progress)
                        .tint(progressColor(for: request.progress))
                    
                    Text(request.prompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Timer visualization
                TimeoutTimerView(
                    elapsed: request.elapsedTime,
                    total: request.timeout
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    func progressColor(for progress: Double) -> Color {
        if progress < 0.5 {
            return .green
        } else if progress < 0.8 {
            return .orange
        } else {
            return .red
        }
    }
}

struct TimeoutTimerView: View {
    let elapsed: TimeInterval
    let total: TimeInterval
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: min(elapsed / total, 1.0))
                    .stroke(timerColor, lineWidth: 10)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: elapsed)
                
                // Time text
                VStack {
                    Text(String(format: "%.1f", elapsed))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Text("seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 100)
    }
    
    var timerColor: Color {
        let progress = elapsed / total
        if progress < 0.5 {
            return .green
        } else if progress < 0.8 {
            return .orange
        } else {
            return .red
        }
    }
}

struct TimeoutStrategiesView: View {
    @ObservedObject var manager: TimeoutManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Operation Timeouts")
                .font(.headline)
            
            ForEach(TimeoutManager.OperationType.allCases, id: \.self) { operation in
                OperationTimeoutRow(
                    operation: operation,
                    strategy: manager.strategy,
                    baseTimeout: 30
                )
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct OperationTimeoutRow: View {
    let operation: TimeoutManager.OperationType
    let strategy: TimeoutManager.TimeoutStrategy
    let baseTimeout: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(operation.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(operation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(calculatedTimeout))s")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            // Visual timeout bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: timeoutWidth(in: geometry.size.width), height: 4)
                }
                .cornerRadius(2)
            }
            .frame(height: 4)
        }
        .padding(.vertical, 8)
    }
    
    var calculatedTimeout: TimeInterval {
        strategy.calculateTimeout(for: operation, baseTimeout: baseTimeout)
    }
    
    func timeoutWidth(in totalWidth: CGFloat) -> CGFloat {
        let maxTimeout: TimeInterval = 120
        return totalWidth * CGFloat(calculatedTimeout / maxTimeout)
    }
}

struct TimeoutTestControls: View {
    @ObservedObject var manager: TimeoutManager
    let customTimeout: TimeInterval
    @Binding var testPrompt: String
    @State private var selectedOperation: TimeoutManager.OperationType = .moderate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Timeouts")
                .font(.headline)
            
            // Operation selector
            Picker("Operation Type", selection: $selectedOperation) {
                ForEach(TimeoutManager.OperationType.allCases, id: \.self) { operation in
                    Text(operation.rawValue).tag(operation)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            // Test prompt
            TextField("Test prompt", text: $testPrompt)
                .textFieldStyle(.roundedBorder)
            
            // Test button
            Button("Test Request") {
                Task {
                    let timeout = manager.strategy.calculateTimeout(
                        for: selectedOperation,
                        baseTimeout: customTimeout
                    )
                    
                    await manager.sendRequest(
                        prompt: testPrompt,
                        timeout: timeout,
                        operation: selectedOperation
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.hasActiveRequest)
            
            // Statistics
            if manager.stats.totalRequests > 0 {
                HStack(spacing: 20) {
                    StatCard(
                        title: "Success Rate",
                        value: String(format: "%.1f%%", (1 - manager.stats.timeoutRate) * 100),
                        color: .green
                    )
                    
                    StatCard(
                        title: "Avg Response",
                        value: String(format: "%.1fs", manager.stats.averageResponseTime),
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Timeouts",
                        value: "\(manager.stats.timedOutRequests)",
                        color: .red
                    )
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TimeoutHistoryView: View {
    let history: [TimeoutManager.TimeoutEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeout History")
                .font(.headline)
            
            if history.isEmpty {
                Text("No timeout events")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(history.prefix(10)) { event in
                    TimeoutEventRow(event: event)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct TimeoutEventRow: View {
    let event: TimeoutManager.TimeoutEvent
    
    var body: some View {
        HStack {
            resultIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.operation.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack {
                    Text(event.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(event.actualDuration))s / \(Int(event.requestedTimeout))s")
                        .font(.caption2)
                        .foregroundColor(durationColor)
                }
            }
            
            Spacer()
            
            resultBadge
        }
        .padding(.vertical, 4)
    }
    
    var resultIcon: some View {
        Group {
            switch event.result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .timeout:
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundColor(.red)
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
    }
    
    var resultBadge: some View {
        Group {
            switch event.result {
            case .success:
                Text("Success")
                    .foregroundColor(.green)
            case .timeout:
                Text("Timeout")
                    .foregroundColor(.red)
            case .cancelled:
                Text("Cancelled")
                    .foregroundColor(.orange)
            case .error:
                Text("Error")
                    .foregroundColor(.red)
            }
        }
        .font(.caption2)
        .fontWeight(.medium)
    }
    
    var durationColor: Color {
        if event.actualDuration < event.requestedTimeout * 0.5 {
            return .green
        } else if event.actualDuration < event.requestedTimeout * 0.8 {
            return .orange
        } else {
            return .red
        }
    }
}

struct TimeoutBestPracticesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Timeout Best Practices", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 12) {
                BestPractice(
                    title: "Set Appropriate Timeouts",
                    description: "Match timeout to operation complexity",
                    icon: "timer"
                )
                
                BestPractice(
                    title: "Progressive Timeouts",
                    description: "Increase timeout on retries",
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                BestPractice(
                    title: "User Feedback",
                    description: "Show progress and remaining time",
                    icon: "person.crop.circle.badge.clock"
                )
                
                BestPractice(
                    title: "Graceful Degradation",
                    description: "Provide partial results on timeout",
                    icon: "rectangle.stack.badge.minus"
                )
                
                BestPractice(
                    title: "Monitor and Adjust",
                    description: "Track timeout rates and optimize",
                    icon: "chart.bar"
                )
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

struct BestPractice: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.yellow)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}