import SwiftUI
import DeepSeekKit

// Dealing with rate limiting
struct RateLimitHandlingView: View {
    @StateObject private var rateLimitManager = RateLimitManager()
    @State private var testPrompt = "Tell me a short joke"
    @State private var requestCount = 5
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Rate Limit Handling")
                    .font(.largeTitle)
                    .bold()
                
                // Rate limit status
                RateLimitStatusView(manager: rateLimitManager)
                
                // Request simulator
                RequestSimulatorView(
                    manager: rateLimitManager,
                    prompt: $testPrompt,
                    requestCount: $requestCount
                )
                
                // Backoff strategy display
                if rateLimitManager.isRateLimited {
                    BackoffStrategyView(manager: rateLimitManager)
                }
                
                // Request history
                RequestHistoryView(requests: rateLimitManager.requestHistory)
                
                // Best practices
                RateLimitBestPracticesView()
            }
            .padding()
        }
    }
}

// Rate limit manager with backoff strategies
@MainActor
class RateLimitManager: ObservableObject {
    @Published var isRateLimited = false
    @Published var requestHistory: [RequestRecord] = []
    @Published var currentBackoffStrategy: BackoffStrategy = .exponential
    @Published var rateLimitInfo: RateLimitInfo?
    @Published var isProcessing = false
    @Published var remainingRequests = 100 // Example limit
    @Published var resetTime: Date?
    
    private let client = DeepSeekClient()
    private var retryCount = 0
    private let maxRetries = 5
    
    struct RequestRecord: Identifiable {
        let id = UUID()
        let timestamp: Date
        let prompt: String
        let status: RequestStatus
        let responseTime: TimeInterval?
        let retryAttempt: Int
        
        enum RequestStatus {
            case success
            case rateLimited
            case failed(error: String)
            case retrying(attempt: Int)
        }
    }
    
    struct RateLimitInfo {
        let limit: Int
        let remaining: Int
        let resetTime: Date
        let retryAfter: TimeInterval?
    }
    
    enum BackoffStrategy: String, CaseIterable {
        case fixed = "Fixed Delay"
        case linear = "Linear Backoff"
        case exponential = "Exponential Backoff"
        case jittered = "Exponential with Jitter"
        
        func calculateDelay(for attempt: Int) -> TimeInterval {
            switch self {
            case .fixed:
                return 60 // Fixed 60 seconds
            case .linear:
                return TimeInterval(attempt * 30) // 30s, 60s, 90s...
            case .exponential:
                return TimeInterval(pow(2.0, Double(attempt - 1)) * 10) // 10s, 20s, 40s...
            case .jittered:
                let baseDelay = pow(2.0, Double(attempt - 1)) * 10
                let jitter = Double.random(in: 0.5...1.5)
                return TimeInterval(baseDelay * jitter)
            }
        }
    }
    
    func simulateRequests(prompt: String, count: Int) async {
        isProcessing = true
        
        for i in 0..<count {
            // Simulate rate limit after certain requests
            if i >= 3 && !isRateLimited {
                await handleRateLimit()
            } else {
                await sendRequest(prompt: "\(prompt) #\(i + 1)")
            }
            
            // Small delay between requests
            if i < count - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }
        
        isProcessing = false
    }
    
    func sendRequest(prompt: String, isRetry: Bool = false) async {
        let startTime = Date()
        
        let record = RequestRecord(
            timestamp: startTime,
            prompt: prompt,
            status: isRetry ? .retrying(attempt: retryCount) : .success,
            responseTime: nil,
            retryAttempt: retryCount
        )
        
        do {
            if isRateLimited && !isRetry {
                throw DeepSeekError.rateLimitExceeded
            }
            
            // Simulate API call
            let _ = try await client.sendMessage(prompt)
            
            let responseTime = Date().timeIntervalSince(startTime)
            
            let successRecord = RequestRecord(
                timestamp: startTime,
                prompt: prompt,
                status: .success,
                responseTime: responseTime,
                retryAttempt: retryCount
            )
            
            requestHistory.insert(successRecord, at: 0)
            
            // Update rate limit info
            remainingRequests = max(0, remainingRequests - 1)
            
            // Reset retry count on success
            if isRetry {
                retryCount = 0
                isRateLimited = false
            }
            
        } catch DeepSeekError.rateLimitExceeded {
            let rateLimitRecord = RequestRecord(
                timestamp: startTime,
                prompt: prompt,
                status: .rateLimited,
                responseTime: nil,
                retryAttempt: retryCount
            )
            
            requestHistory.insert(rateLimitRecord, at: 0)
            
            await handleRateLimit()
            
            // Retry with backoff
            if retryCount < maxRetries {
                await retryWithBackoff(prompt: prompt)
            }
            
        } catch {
            let errorRecord = RequestRecord(
                timestamp: startTime,
                prompt: prompt,
                status: .failed(error: error.localizedDescription),
                responseTime: nil,
                retryAttempt: retryCount
            )
            
            requestHistory.insert(errorRecord, at: 0)
        }
    }
    
    private func handleRateLimit() async {
        isRateLimited = true
        
        // Simulate rate limit info from headers
        let resetTime = Date().addingTimeInterval(60) // Reset in 60 seconds
        self.resetTime = resetTime
        
        rateLimitInfo = RateLimitInfo(
            limit: 100,
            remaining: 0,
            resetTime: resetTime,
            retryAfter: 60
        )
        
        remainingRequests = 0
    }
    
    private func retryWithBackoff(prompt: String) async {
        retryCount += 1
        
        let delay = currentBackoffStrategy.calculateDelay(for: retryCount)
        
        // Show retry status
        let retryRecord = RequestRecord(
            timestamp: Date(),
            prompt: prompt,
            status: .retrying(attempt: retryCount),
            responseTime: nil,
            retryAttempt: retryCount
        )
        requestHistory.insert(retryRecord, at: 0)
        
        // Wait for backoff period
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Retry the request
        await sendRequest(prompt: prompt, isRetry: true)
    }
    
    func resetRateLimit() {
        isRateLimited = false
        remainingRequests = 100
        resetTime = nil
        rateLimitInfo = nil
        retryCount = 0
    }
}

// UI Components
struct RateLimitStatusView: View {
    @ObservedObject var manager: RateLimitManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rate Limit Status")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(manager.isRateLimited ? Color.red : Color.green)
                            .frame(width: 12, height: 12)
                        
                        Text(manager.isRateLimited ? "Rate Limited" : "Normal")
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(manager.remainingRequests)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Requests left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(
                            width: geometry.size.width * progressPercentage,
                            height: 8
                        )
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            if let resetTime = manager.resetTime {
                TimeUntilResetView(resetTime: resetTime)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var progressPercentage: Double {
        Double(manager.remainingRequests) / 100.0
    }
    
    var progressColor: Color {
        if manager.remainingRequests > 50 {
            return .green
        } else if manager.remainingRequests > 20 {
            return .orange
        } else {
            return .red
        }
    }
}

struct TimeUntilResetView: View {
    let resetTime: Date
    @State private var timeRemaining: TimeInterval = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.blue)
            
            Text("Reset in: \(timeString)")
                .font(.caption)
                .monospacedDigit()
        }
        .onReceive(timer) { _ in
            timeRemaining = resetTime.timeIntervalSinceNow
        }
        .onAppear {
            timeRemaining = resetTime.timeIntervalSinceNow
        }
    }
    
    var timeString: String {
        let minutes = Int(max(0, timeRemaining)) / 60
        let seconds = Int(max(0, timeRemaining)) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RequestSimulatorView: View {
    @ObservedObject var manager: RateLimitManager
    @Binding var prompt: String
    @Binding var requestCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Request Simulator")
                .font(.headline)
            
            TextField("Prompt", text: $prompt)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Number of requests:")
                Stepper("\(requestCount)", value: $requestCount, in: 1...10)
            }
            
            HStack {
                Button("Send Requests") {
                    Task {
                        await manager.simulateRequests(prompt: prompt, count: requestCount)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.isProcessing)
                
                Button("Reset Limits") {
                    manager.resetRateLimit()
                }
                .buttonStyle(.bordered)
                
                if manager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct BackoffStrategyView: View {
    @ObservedObject var manager: RateLimitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Backoff Strategy")
                .font(.headline)
            
            Picker("Strategy", selection: $manager.currentBackoffStrategy) {
                ForEach(RateLimitManager.BackoffStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.rawValue).tag(strategy)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Backoff visualization
            BackoffVisualization(strategy: manager.currentBackoffStrategy)
            
            // Current retry info
            if manager.retryCount > 0 {
                HStack {
                    Label("Retry attempt \(manager.retryCount) of \(5)", systemImage: "arrow.clockwise")
                    Spacer()
                    Text("Next delay: \(Int(manager.currentBackoffStrategy.calculateDelay(for: manager.retryCount + 1)))s")
                        .font(.caption)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

struct BackoffVisualization: View {
    let strategy: RateLimitManager.BackoffStrategy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Retry Delays")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { attempt in
                    VStack {
                        Text("\(Int(strategy.calculateDelay(for: attempt)))s")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 40, height: delayHeight(for: attempt))
                        
                        Text("#\(attempt)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    func delayHeight(for attempt: Int) -> CGFloat {
        let delay = strategy.calculateDelay(for: attempt)
        let maxDelay = strategy.calculateDelay(for: 5)
        return CGFloat(delay / maxDelay) * 60 + 10
    }
}

struct RequestHistoryView: View {
    let requests: [RateLimitManager.RequestRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Request History")
                .font(.headline)
            
            if requests.isEmpty {
                Text("No requests yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(requests.prefix(10)) { request in
                    RequestRecordView(record: request)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RequestRecordView: View {
    let record: RateLimitManager.RequestRecord
    
    var body: some View {
        HStack {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(record.prompt)
                    .font(.caption)
                    .lineLimit(1)
                
                HStack {
                    Text(record.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let responseTime = record.responseTime {
                        Text("• \(String(format: "%.2fs", responseTime))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if record.retryAttempt > 0 {
                        Text("• Retry #\(record.retryAttempt)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    var statusIcon: some View {
        Group {
            switch record.status {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .rateLimited:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .retrying:
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }
}

struct RateLimitBestPracticesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Best Practices", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                BestPracticeItem(
                    icon: "gauge",
                    title: "Monitor Usage",
                    description: "Track your API usage and implement client-side rate limiting"
                )
                
                BestPracticeItem(
                    icon: "arrow.clockwise",
                    title: "Implement Retry Logic",
                    description: "Use exponential backoff with jitter for retries"
                )
                
                BestPracticeItem(
                    icon: "tray.full",
                    title: "Batch Requests",
                    description: "Combine multiple operations when possible"
                )
                
                BestPracticeItem(
                    icon: "clock.arrow.circlepath",
                    title: "Cache Responses",
                    description: "Cache frequently requested data to reduce API calls"
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct BestPracticeItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 20)
            
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