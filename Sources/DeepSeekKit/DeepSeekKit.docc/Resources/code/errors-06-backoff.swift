import SwiftUI
import DeepSeekKit

// Implementing exponential backoff for retries
struct ExponentialBackoffView: View {
    @StateObject private var backoffManager = BackoffManager()
    @State private var selectedStrategy: BackoffStrategy = .exponential
    @State private var simulateFailures = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Exponential Backoff")
                    .font(.largeTitle)
                    .bold()
                
                // Strategy selector
                BackoffStrategySelector(
                    selectedStrategy: $selectedStrategy,
                    manager: backoffManager
                )
                
                // Backoff visualization
                BackoffVisualizationView(
                    strategy: selectedStrategy,
                    currentAttempt: backoffManager.currentAttempt
                )
                
                // Live demonstration
                LiveBackoffDemo(
                    manager: backoffManager,
                    simulateFailures: $simulateFailures
                )
                
                // Backoff calculator
                BackoffCalculator(strategy: selectedStrategy)
                
                // Best practices
                BackoffBestPractices()
            }
            .padding()
        }
    }
}

// Backoff strategies
enum BackoffStrategy: String, CaseIterable {
    case fixed = "Fixed Delay"
    case linear = "Linear"
    case exponential = "Exponential"
    case exponentialWithJitter = "Exponential with Jitter"
    case decorrelatedJitter = "Decorrelated Jitter"
    case customAdaptive = "Custom Adaptive"
    
    func calculateDelay(attempt: Int, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 60.0) -> TimeInterval {
        let delay: TimeInterval
        
        switch self {
        case .fixed:
            delay = baseDelay
            
        case .linear:
            delay = baseDelay * TimeInterval(attempt)
            
        case .exponential:
            delay = baseDelay * pow(2.0, TimeInterval(attempt - 1))
            
        case .exponentialWithJitter:
            let exponentialDelay = baseDelay * pow(2.0, TimeInterval(attempt - 1))
            let jitter = TimeInterval.random(in: 0...1.0)
            delay = exponentialDelay * jitter
            
        case .decorrelatedJitter:
            // AWS recommended algorithm
            let temp = baseDelay * pow(3.0, TimeInterval(attempt - 1))
            delay = TimeInterval.random(in: baseDelay...temp)
            
        case .customAdaptive:
            // Adaptive based on error type and history
            let base = baseDelay * pow(1.5, TimeInterval(attempt - 1))
            let adaptiveFactor = TimeInterval.random(in: 0.8...1.2)
            delay = base * adaptiveFactor
        }
        
        return min(delay, maxDelay)
    }
    
    var description: String {
        switch self {
        case .fixed:
            return "Same delay for all retries"
        case .linear:
            return "Delay increases linearly"
        case .exponential:
            return "Delay doubles each retry"
        case .exponentialWithJitter:
            return "Exponential with randomness"
        case .decorrelatedJitter:
            return "AWS recommended pattern"
        case .customAdaptive:
            return "Adapts to error patterns"
        }
    }
}

// Backoff manager
@MainActor
class BackoffManager: ObservableObject {
    @Published var currentAttempt = 0
    @Published var isRetrying = false
    @Published var nextRetryIn: TimeInterval = 0
    @Published var retryHistory: [RetryAttempt] = []
    @Published var successRate: Double = 0
    @Published var averageDelay: TimeInterval = 0
    
    private let client = DeepSeekClient()
    private var retryTask: Task<Void, Never>?
    private let maxRetries = 5
    
    struct RetryAttempt: Identifiable {
        let id = UUID()
        let attemptNumber: Int
        let delay: TimeInterval
        let timestamp: Date
        let result: Result
        
        enum Result {
            case success
            case failure(error: String)
            case cancelled
        }
    }
    
    func startRetrySequence(
        strategy: BackoffStrategy,
        simulateFailures: Bool
    ) async {
        isRetrying = true
        currentAttempt = 0
        retryHistory = []
        
        retryTask = Task {
            await performRetries(strategy: strategy, simulateFailures: simulateFailures)
        }
        
        await retryTask?.value
        isRetrying = false
        updateStatistics()
    }
    
    private func performRetries(
        strategy: BackoffStrategy,
        simulateFailures: Bool
    ) async {
        for attempt in 1...maxRetries {
            currentAttempt = attempt
            
            // Calculate delay
            let delay = strategy.calculateDelay(attempt: attempt)
            nextRetryIn = delay
            
            // Wait with countdown
            await countdownDelay(delay)
            
            // Attempt request
            let result = await attemptRequest(
                attempt: attempt,
                simulateFailure: simulateFailures && attempt < 3
            )
            
            // Record attempt
            let retryAttempt = RetryAttempt(
                attemptNumber: attempt,
                delay: delay,
                timestamp: Date(),
                result: result
            )
            retryHistory.append(retryAttempt)
            
            // Check result
            switch result {
            case .success:
                return // Success, stop retrying
            case .failure:
                if attempt == maxRetries {
                    // Max retries reached
                    return
                }
                // Continue to next retry
            case .cancelled:
                return
            }
        }
    }
    
    private func countdownDelay(_ delay: TimeInterval) async {
        let steps = Int(delay * 10) // Update every 0.1 second
        
        for i in 0..<steps {
            if Task.isCancelled { break }
            
            let elapsed = TimeInterval(i) / 10.0
            nextRetryIn = delay - elapsed
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        nextRetryIn = 0
    }
    
    private func attemptRequest(
        attempt: Int,
        simulateFailure: Bool
    ) async -> RetryAttempt.Result {
        do {
            if simulateFailure {
                throw DeepSeekError.apiError(
                    statusCode: 500,
                    message: "Simulated server error"
                )
            }
            
            // Real request
            _ = try await client.sendMessage("Test message for retry \(attempt)")
            return .success
        } catch {
            return .failure(error: error.localizedDescription)
        }
    }
    
    func cancelRetries() {
        retryTask?.cancel()
        isRetrying = false
        currentAttempt = 0
        nextRetryIn = 0
    }
    
    private func updateStatistics() {
        let successCount = retryHistory.filter { 
            if case .success = $0.result { return true }
            return false
        }.count
        
        successRate = retryHistory.isEmpty ? 0 : 
            Double(successCount) / Double(retryHistory.count)
        
        let totalDelay = retryHistory.reduce(0) { $0 + $1.delay }
        averageDelay = retryHistory.isEmpty ? 0 : 
            totalDelay / Double(retryHistory.count)
    }
}

// UI Components
struct BackoffStrategySelector: View {
    @Binding var selectedStrategy: BackoffStrategy
    @ObservedObject var manager: BackoffManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Backoff Strategy")
                .font(.headline)
            
            ForEach(BackoffStrategy.allCases, id: \.self) { strategy in
                BackoffStrategyOption(
                    strategy: strategy,
                    isSelected: selectedStrategy == strategy,
                    action: {
                        selectedStrategy = strategy
                        manager.cancelRetries()
                    }
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct BackoffStrategyOption: View {
    let strategy: BackoffStrategy
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(strategy.rawValue)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .medium : .regular)
                    
                    Text(strategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct BackoffVisualizationView: View {
    let strategy: BackoffStrategy
    let currentAttempt: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delay Pattern")
                .font(.headline)
            
            // Graph
            GeometryReader { geometry in
                ZStack {
                    // Background grid
                    BackoffGrid()
                    
                    // Delay curve
                    BackoffCurve(
                        strategy: strategy,
                        size: geometry.size,
                        currentAttempt: currentAttempt
                    )
                }
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            
            // Delay values
            HStack {
                ForEach(1...5, id: \.self) { attempt in
                    DelayValueView(
                        attempt: attempt,
                        delay: strategy.calculateDelay(attempt: attempt),
                        isCurrent: attempt == currentAttempt
                    )
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct BackoffGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Horizontal lines
                for i in 0...4 {
                    let y = geometry.size.height * CGFloat(i) / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                
                // Vertical lines
                for i in 0...5 {
                    let x = geometry.size.width * CGFloat(i) / 5
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
            }
            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        }
    }
}

struct BackoffCurve: View {
    let strategy: BackoffStrategy
    let size: CGSize
    let currentAttempt: Int
    
    var body: some View {
        ZStack {
            // Curve
            Path { path in
                for attempt in 1...5 {
                    let x = size.width * CGFloat(attempt - 1) / 4
                    let delay = strategy.calculateDelay(attempt: attempt)
                    let y = size.height - (size.height * CGFloat(delay) / 60)
                    
                    if attempt == 1 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.blue, lineWidth: 2)
            
            // Points
            ForEach(1...5, id: \.self) { attempt in
                let x = size.width * CGFloat(attempt - 1) / 4
                let delay = strategy.calculateDelay(attempt: attempt)
                let y = size.height - (size.height * CGFloat(delay) / 60)
                
                Circle()
                    .fill(attempt == currentAttempt ? Color.blue : Color.white)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .position(x: x, y: y)
            }
        }
    }
}

struct DelayValueView: View {
    let attempt: Int
    let delay: TimeInterval
    let isCurrent: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1fs", delay))
                .font(.caption)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundColor(isCurrent ? .blue : .primary)
            
            Text("Try \(attempt)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isCurrent ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct LiveBackoffDemo: View {
    @ObservedObject var manager: BackoffManager
    @Binding var simulateFailures: Bool
    @State private var selectedStrategy: BackoffStrategy = .exponential
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Live Demonstration")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Simulate Failures", isOn: $simulateFailures)
                    .toggleStyle(SwitchToggleStyle(tint: .red))
            }
            
            // Progress
            if manager.isRetrying {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Attempt \(manager.currentAttempt) of 5")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if manager.nextRetryIn > 0 {
                            Text("Next retry in: \(String(format: "%.1f", manager.nextRetryIn))s")
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }
                    
                    ProgressView(value: Double(manager.currentAttempt), total: 5)
                }
            }
            
            // Controls
            HStack {
                Picker("Strategy", selection: $selectedStrategy) {
                    ForEach(BackoffStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(manager.isRetrying)
                
                Spacer()
                
                if manager.isRetrying {
                    Button("Cancel", role: .destructive) {
                        manager.cancelRetries()
                    }
                } else {
                    Button("Start Demo") {
                        Task {
                            await manager.startRetrySequence(
                                strategy: selectedStrategy,
                                simulateFailures: simulateFailures
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // History
            if !manager.retryHistory.isEmpty {
                RetryHistoryView(history: manager.retryHistory)
            }
            
            // Statistics
            if !manager.retryHistory.isEmpty {
                HStack(spacing: 20) {
                    StatView(
                        label: "Success Rate",
                        value: String(format: "%.0f%%", manager.successRate * 100)
                    )
                    
                    StatView(
                        label: "Avg Delay",
                        value: String(format: "%.1fs", manager.averageDelay)
                    )
                    
                    StatView(
                        label: "Total Attempts",
                        value: "\(manager.retryHistory.count)"
                    )
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RetryHistoryView: View {
    let history: [BackoffManager.RetryAttempt]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Retry History")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(history) { attempt in
                HStack {
                    Text("#\(attempt.attemptNumber)")
                        .font(.caption)
                        .frame(width: 30)
                    
                    Text("Delay: \(String(format: "%.1fs", attempt.delay))")
                        .font(.caption)
                    
                    Spacer()
                    
                    ResultBadge(result: attempt.result)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ResultBadge: View {
    let result: BackoffManager.RetryAttempt.Result
    
    var body: some View {
        Group {
            switch result {
            case .success:
                Label("Success", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Label("Failed", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .cancelled:
                Label("Cancelled", systemImage: "stop.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption2)
    }
}

struct StatView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BackoffCalculator: View {
    let strategy: BackoffStrategy
    @State private var baseDelay: Double = 1.0
    @State private var maxDelay: Double = 60.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Backoff Calculator")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Base Delay:")
                    Slider(value: $baseDelay, in: 0.1...10, step: 0.1)
                    Text("\(String(format: "%.1f", baseDelay))s")
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Max Delay:")
                    Slider(value: $maxDelay, in: 10...300, step: 10)
                    Text("\(String(format: "%.0f", maxDelay))s")
                        .frame(width: 50)
                }
            }
            
            // Calculated delays
            VStack(alignment: .leading, spacing: 8) {
                Text("Calculated Delays")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(1...10, id: \.self) { attempt in
                    HStack {
                        Text("Attempt \(attempt):")
                            .font(.caption)
                        
                        Spacer()
                        
                        let delay = strategy.calculateDelay(
                            attempt: attempt,
                            baseDelay: baseDelay,
                            maxDelay: maxDelay
                        )
                        
                        Text(String(format: "%.2f seconds", delay))
                            .font(.caption)
                            .fontFamily(.monospaced)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct BackoffBestPractices: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Best Practices", systemImage: "star.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 12) {
                PracticeItem(
                    title: "Add Jitter",
                    description: "Prevent thundering herd by adding randomness to delays"
                )
                
                PracticeItem(
                    title: "Set Maximum Delay",
                    description: "Cap delays to prevent excessive waiting"
                )
                
                PracticeItem(
                    title: "Consider Error Type",
                    description: "Different errors may need different backoff strategies"
                )
                
                PracticeItem(
                    title: "Circuit Breaker",
                    description: "Stop retrying after repeated failures"
                )
                
                PracticeItem(
                    title: "Monitor and Adjust",
                    description: "Track success rates and tune parameters"
                )
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

struct PracticeItem: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}