import SwiftUI
import DeepSeekKit

// Circuit breaker pattern for repeated failures
struct CircuitBreakerView: View {
    @StateObject private var circuitBreaker = CircuitBreakerManager()
    @State private var testPrompt = "Test message"
    @State private var simulateFailures = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Circuit Breaker Pattern")
                    .font(.largeTitle)
                    .bold()
                
                // Circuit state display
                CircuitStateView(breaker: circuitBreaker)
                
                // Circuit visualization
                CircuitVisualization(breaker: circuitBreaker)
                
                // Configuration
                CircuitConfiguration(breaker: circuitBreaker)
                
                // Test controls
                CircuitTestControls(
                    breaker: circuitBreaker,
                    testPrompt: $testPrompt,
                    simulateFailures: $simulateFailures
                )
                
                // Metrics dashboard
                CircuitMetricsDashboard(breaker: circuitBreaker)
                
                // Event log
                CircuitEventLog(events: circuitBreaker.eventLog)
            }
            .padding()
        }
    }
}

// Circuit breaker states
enum CircuitState {
    case closed      // Normal operation
    case open        // Failing, reject requests
    case halfOpen    // Testing if service recovered
    
    var color: Color {
        switch self {
        case .closed: return .green
        case .open: return .red
        case .halfOpen: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .closed: return "checkmark.circle.fill"
        case .open: return "xmark.circle.fill"
        case .halfOpen: return "questionmark.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .closed:
            return "Circuit is closed. Requests are flowing normally."
        case .open:
            return "Circuit is open. Requests are being rejected to protect the system."
        case .halfOpen:
            return "Circuit is half-open. Testing if the service has recovered."
        }
    }
}

// Circuit breaker manager
@MainActor
class CircuitBreakerManager: ObservableObject {
    @Published var state: CircuitState = .closed
    @Published var failureCount = 0
    @Published var successCount = 0
    @Published var lastFailureTime: Date?
    @Published var nextRetryTime: Date?
    @Published var eventLog: [CircuitEvent] = []
    @Published var metrics = CircuitMetrics()
    
    // Configuration
    @Published var failureThreshold = 5
    @Published var successThreshold = 3
    @Published var timeout: TimeInterval = 60
    @Published var halfOpenTimeout: TimeInterval = 30
    
    private let client = DeepSeekClient()
    private var resetTimer: Timer?
    private var halfOpenTimer: Timer?
    
    struct CircuitEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: EventType
        let description: String
        let oldState: CircuitState?
        let newState: CircuitState?
        
        enum EventType {
            case stateChange
            case requestSuccess
            case requestFailure
            case requestRejected
            case reset
        }
    }
    
    struct CircuitMetrics {
        var totalRequests = 0
        var successfulRequests = 0
        var failedRequests = 0
        var rejectedRequests = 0
        var stateChanges = 0
        var uptime: TimeInterval = 0
        var downtime: TimeInterval = 0
        var lastDowntime: Date?
        
        var successRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(successfulRequests) / Double(totalRequests)
        }
        
        var availability: Double {
            let total = uptime + downtime
            guard total > 0 else { return 1.0 }
            return uptime / total
        }
    }
    
    func sendRequest(_ prompt: String, simulateFailure: Bool) async {
        metrics.totalRequests += 1
        
        // Check circuit state
        switch state {
        case .open:
            handleOpenCircuit()
            return
            
        case .halfOpen:
            await handleHalfOpenRequest(prompt: prompt, simulateFailure: simulateFailure)
            
        case .closed:
            await handleClosedRequest(prompt: prompt, simulateFailure: simulateFailure)
        }
    }
    
    private func handleOpenCircuit() {
        metrics.rejectedRequests += 1
        logEvent(
            type: .requestRejected,
            description: "Request rejected - circuit is open"
        )
    }
    
    private func handleHalfOpenRequest(prompt: String, simulateFailure: Bool) async {
        do {
            if simulateFailure {
                throw DeepSeekError.networkError(URLError(.notConnectedToInternet))
            }
            
            _ = try await client.sendMessage(prompt)
            
            // Success in half-open state
            successCount += 1
            metrics.successfulRequests += 1
            
            logEvent(
                type: .requestSuccess,
                description: "Success in half-open state (\(successCount)/\(successThreshold))"
            )
            
            // Check if we should close the circuit
            if successCount >= successThreshold {
                transitionTo(.closed)
                successCount = 0
                failureCount = 0
            }
            
        } catch {
            // Failure in half-open state - immediately open
            failureCount += 1
            metrics.failedRequests += 1
            lastFailureTime = Date()
            
            logEvent(
                type: .requestFailure,
                description: "Failure in half-open state - reopening circuit"
            )
            
            transitionTo(.open)
            successCount = 0
        }
    }
    
    private func handleClosedRequest(prompt: String, simulateFailure: Bool) async {
        do {
            if simulateFailure {
                throw DeepSeekError.networkError(URLError(.timedOut))
            }
            
            _ = try await client.sendMessage(prompt)
            
            // Success
            metrics.successfulRequests += 1
            
            // Reset failure count on success
            if failureCount > 0 {
                failureCount = 0
            }
            
            logEvent(
                type: .requestSuccess,
                description: "Request successful"
            )
            
        } catch {
            // Failure
            failureCount += 1
            metrics.failedRequests += 1
            lastFailureTime = Date()
            
            logEvent(
                type: .requestFailure,
                description: "Request failed (\(failureCount)/\(failureThreshold))"
            )
            
            // Check if we should open the circuit
            if failureCount >= failureThreshold {
                transitionTo(.open)
            }
        }
    }
    
    private func transitionTo(_ newState: CircuitState) {
        let oldState = state
        state = newState
        metrics.stateChanges += 1
        
        logEvent(
            type: .stateChange,
            description: "Circuit transitioned from \(oldState) to \(newState)",
            oldState: oldState,
            newState: newState
        )
        
        // Handle state-specific logic
        switch newState {
        case .open:
            metrics.lastDowntime = Date()
            scheduleReset()
            
        case .halfOpen:
            successCount = 0
            scheduleHalfOpenTimeout()
            
        case .closed:
            failureCount = 0
            successCount = 0
            cancelTimers()
        }
    }
    
    private func scheduleReset() {
        cancelTimers()
        
        nextRetryTime = Date().addingTimeInterval(timeout)
        
        resetTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
            Task { @MainActor in
                self.transitionTo(.halfOpen)
            }
        }
    }
    
    private func scheduleHalfOpenTimeout() {
        halfOpenTimer = Timer.scheduledTimer(
            withTimeInterval: halfOpenTimeout,
            repeats: false
        ) { _ in
            Task { @MainActor in
                if self.state == .halfOpen {
                    // Timeout in half-open state - go back to open
                    self.logEvent(
                        type: .stateChange,
                        description: "Half-open timeout - reopening circuit"
                    )
                    self.transitionTo(.open)
                }
            }
        }
    }
    
    private func cancelTimers() {
        resetTimer?.invalidate()
        halfOpenTimer?.invalidate()
        resetTimer = nil
        halfOpenTimer = nil
        nextRetryTime = nil
    }
    
    private func logEvent(
        type: CircuitEvent.EventType,
        description: String,
        oldState: CircuitState? = nil,
        newState: CircuitState? = nil
    ) {
        let event = CircuitEvent(
            timestamp: Date(),
            type: type,
            description: description,
            oldState: oldState,
            newState: newState
        )
        
        eventLog.insert(event, at: 0)
        
        // Keep only recent events
        if eventLog.count > 50 {
            eventLog = Array(eventLog.prefix(50))
        }
    }
    
    func reset() {
        cancelTimers()
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
        nextRetryTime = nil
        metrics = CircuitMetrics()
        
        logEvent(
            type: .reset,
            description: "Circuit breaker manually reset"
        )
    }
    
    func updateMetrics() {
        // Update uptime/downtime
        if let lastDowntime = metrics.lastDowntime {
            if state == .open {
                metrics.downtime = Date().timeIntervalSince(lastDowntime)
            } else {
                // Circuit recovered
                metrics.uptime = Date().timeIntervalSince(lastDowntime)
            }
        }
    }
}

// UI Components
struct CircuitStateView: View {
    @ObservedObject var breaker: CircuitBreakerManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: breaker.state.icon)
                    .font(.largeTitle)
                    .foregroundColor(breaker.state.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Circuit State: \(stateText)")
                        .font(.title2)
                        .bold()
                    
                    Text(breaker.state.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // State details
            HStack(spacing: 20) {
                StateDetail(
                    label: "Failures",
                    value: "\(breaker.failureCount)/\(breaker.failureThreshold)",
                    color: .red
                )
                
                if breaker.state == .halfOpen {
                    StateDetail(
                        label: "Successes",
                        value: "\(breaker.successCount)/\(breaker.successThreshold)",
                        color: .green
                    )
                }
                
                if let nextRetry = breaker.nextRetryTime {
                    TimeUntilRetry(retryTime: nextRetry)
                }
            }
        }
        .padding()
        .background(breaker.state.color.opacity(0.1))
        .cornerRadius(12)
    }
    
    var stateText: String {
        switch breaker.state {
        case .closed: return "CLOSED"
        case .open: return "OPEN"
        case .halfOpen: return "HALF-OPEN"
        }
    }
}

struct StateDetail: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TimeUntilRetry: View {
    let retryTime: Date
    @State private var timeRemaining: String = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 4) {
            Text(timeRemaining)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text("Until Retry")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onReceive(timer) { _ in
            updateTime()
        }
        .onAppear {
            updateTime()
        }
    }
    
    func updateTime() {
        let remaining = retryTime.timeIntervalSinceNow
        if remaining > 0 {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            timeRemaining = String(format: "%02d:%02d", minutes, seconds)
        } else {
            timeRemaining = "00:00"
        }
    }
}

struct CircuitVisualization: View {
    @ObservedObject var breaker: CircuitBreakerManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Circuit Flow")
                .font(.headline)
            
            ZStack {
                // Circuit diagram
                CircuitDiagram(state: breaker.state)
                
                // Flow animation
                if breaker.state == .closed {
                    FlowAnimation()
                }
            }
            .frame(height: 150)
            
            // State transitions
            HStack(spacing: 20) {
                TransitionArrow(
                    from: "CLOSED",
                    to: "OPEN",
                    condition: "\(breaker.failureThreshold) failures"
                )
                
                TransitionArrow(
                    from: "OPEN",
                    to: "HALF-OPEN",
                    condition: "After \(Int(breaker.timeout))s"
                )
                
                TransitionArrow(
                    from: "HALF-OPEN",
                    to: "CLOSED",
                    condition: "\(breaker.successThreshold) successes"
                )
            }
            .font(.caption)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct CircuitDiagram: View {
    let state: CircuitState
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let center = CGPoint(x: width / 2, y: height / 2)
                
                // Draw circuit
                path.move(to: CGPoint(x: 20, y: center.y))
                path.addLine(to: CGPoint(x: center.x - 40, y: center.y))
                
                // Switch
                if state == .open {
                    // Open switch
                    path.move(to: CGPoint(x: center.x - 40, y: center.y))
                    path.addLine(to: CGPoint(x: center.x - 20, y: center.y - 20))
                } else {
                    // Closed switch
                    path.addLine(to: CGPoint(x: center.x + 40, y: center.y))
                }
                
                path.move(to: CGPoint(x: center.x + 40, y: center.y))
                path.addLine(to: CGPoint(x: width - 20, y: center.y))
            }
            .stroke(lineWidth: 3)
            .foregroundColor(state.color)
            
            // Switch handle
            Circle()
                .fill(state.color)
                .frame(width: 20, height: 20)
                .position(
                    x: geometry.size.width / 2 - (state == .open ? 20 : 40),
                    y: geometry.size.height / 2 - (state == .open ? 20 : 0)
                )
        }
    }
}

struct FlowAnimation: View {
    @State private var offset: CGFloat = -50
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 10, height: 10)
            .offset(x: offset)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    offset = 50
                }
            }
    }
}

struct TransitionArrow: View {
    let from: String
    let to: String
    let condition: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(from)
                    .fontWeight(.medium)
                Image(systemName: "arrow.right")
                Text(to)
                    .fontWeight(.medium)
            }
            Text(condition)
                .foregroundColor(.secondary)
        }
    }
}

struct CircuitConfiguration: View {
    @ObservedObject var breaker: CircuitBreakerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(.headline)
            
            VStack(spacing: 12) {
                ConfigSlider(
                    label: "Failure Threshold",
                    value: Binding(
                        get: { Double(breaker.failureThreshold) },
                        set: { breaker.failureThreshold = Int($0) }
                    ),
                    range: 1...10,
                    step: 1
                )
                
                ConfigSlider(
                    label: "Success Threshold",
                    value: Binding(
                        get: { Double(breaker.successThreshold) },
                        set: { breaker.successThreshold = Int($0) }
                    ),
                    range: 1...5,
                    step: 1
                )
                
                ConfigSlider(
                    label: "Reset Timeout",
                    value: $breaker.timeout,
                    range: 10...120,
                    step: 10,
                    format: "%.0f seconds"
                )
                
                ConfigSlider(
                    label: "Half-Open Timeout",
                    value: $breaker.halfOpenTimeout,
                    range: 5...60,
                    step: 5,
                    format: "%.0f seconds"
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ConfigSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var format: String = "%.0f"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: format, value))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.blue)
            }
            
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct CircuitTestControls: View {
    @ObservedObject var breaker: CircuitBreakerManager
    @Binding var testPrompt: String
    @Binding var simulateFailures: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Controls")
                .font(.headline)
            
            Toggle("Simulate Failures", isOn: $simulateFailures)
            
            TextField("Test prompt", text: $testPrompt)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Send Request") {
                    Task {
                        await breaker.sendRequest(testPrompt, simulateFailure: simulateFailures)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(breaker.state == .open)
                
                Button("Send Burst") {
                    Task {
                        for i in 1...10 {
                            await breaker.sendRequest("\(testPrompt) \(i)", simulateFailure: simulateFailures)
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                        }
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Reset", role: .destructive) {
                    breaker.reset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct CircuitMetricsDashboard: View {
    @ObservedObject var breaker: CircuitBreakerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metrics Dashboard")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Total Requests",
                    value: "\(breaker.metrics.totalRequests)",
                    icon: "sum",
                    color: .blue
                )
                
                MetricCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", breaker.metrics.successRate * 100),
                    icon: "percent",
                    color: .green
                )
                
                MetricCard(
                    title: "Rejected",
                    value: "\(breaker.metrics.rejectedRequests)",
                    icon: "xmark.shield",
                    color: .red
                )
                
                MetricCard(
                    title: "Availability",
                    value: String(format: "%.1f%%", breaker.metrics.availability * 100),
                    icon: "checkmark.shield",
                    color: .green
                )
                
                MetricCard(
                    title: "State Changes",
                    value: "\(breaker.metrics.stateChanges)",
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange
                )
                
                MetricCard(
                    title: "Failed",
                    value: "\(breaker.metrics.failedRequests)",
                    icon: "exclamationmark.circle",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                breaker.updateMetrics()
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct CircuitEventLog: View {
    let events: [CircuitBreakerManager.CircuitEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Log")
                .font(.headline)
            
            if events.isEmpty {
                Text("No events yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(events.prefix(10)) { event in
                    EventRow(event: event)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct EventRow: View {
    let event: CircuitBreakerManager.CircuitEvent
    
    var body: some View {
        HStack(alignment: .top) {
            eventIcon
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.description)
                    .font(.caption)
                
                Text(event.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    var eventIcon: some View {
        Group {
            switch event.type {
            case .stateChange:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
            case .requestSuccess:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            case .requestFailure:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
            case .requestRejected:
                Image(systemName: "hand.raised.circle")
                    .foregroundColor(.red)
            case .reset:
                Image(systemName: "arrow.clockwise.circle")
                    .foregroundColor(.blue)
            }
        }
        .font(.caption)
    }
}