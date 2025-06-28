import SwiftUI
import DeepSeekKit

// Handle function errors gracefully
class FunctionErrorHandler: ObservableObject {
    @Published var errorLog: [ErrorEntry] = []
    @Published var recoveryStrategies: [String: RecoveryStrategy] = [:]
    
    struct ErrorEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let functionName: String
        let error: FunctionError
        let recovery: RecoveryAction?
        let resolved: Bool
    }
    
    enum FunctionError: Error {
        case networkError(Error)
        case invalidArguments(String)
        case timeout(TimeInterval)
        case rateLimited(retryAfter: TimeInterval?)
        case unauthorized
        case serviceUnavailable
        case executionFailed(reason: String)
        case unknown(Error)
        
        var localizedDescription: String {
            switch self {
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidArguments(let details):
                return "Invalid arguments: \(details)"
            case .timeout(let duration):
                return "Function timed out after \(Int(duration))s"
            case .rateLimited(let retryAfter):
                if let retry = retryAfter {
                    return "Rate limited. Retry after \(Int(retry))s"
                }
                return "Rate limited. Please try again later"
            case .unauthorized:
                return "Unauthorized. Check API credentials"
            case .serviceUnavailable:
                return "Service temporarily unavailable"
            case .executionFailed(let reason):
                return "Execution failed: \(reason)"
            case .unknown(let error):
                return "Unknown error: \(error.localizedDescription)"
            }
        }
        
        var severity: Severity {
            switch self {
            case .networkError, .timeout, .serviceUnavailable:
                return .warning
            case .invalidArguments, .executionFailed:
                return .error
            case .rateLimited:
                return .info
            case .unauthorized, .unknown:
                return .critical
            }
        }
        
        enum Severity {
            case info, warning, error, critical
            
            var color: Color {
                switch self {
                case .info: return .blue
                case .warning: return .orange
                case .error: return .red
                case .critical: return .purple
                }
            }
            
            var icon: String {
                switch self {
                case .info: return "info.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.circle"
                case .critical: return "exclamationmark.octagon"
                }
            }
        }
    }
    
    enum RecoveryAction {
        case retry(attempts: Int, delay: TimeInterval)
        case fallback(to: String)
        case skip
        case abort
        case manual
        
        var description: String {
            switch self {
            case .retry(let attempts, let delay):
                return "Retry \(attempts) times with \(Int(delay))s delay"
            case .fallback(let alternative):
                return "Fallback to \(alternative)"
            case .skip:
                return "Skip and continue"
            case .abort:
                return "Abort operation"
            case .manual:
                return "Manual intervention required"
            }
        }
    }
    
    struct RecoveryStrategy {
        let errorType: String
        let action: RecoveryAction
        let condition: (FunctionError) -> Bool
    }
    
    init() {
        setupDefaultStrategies()
    }
    
    private func setupDefaultStrategies() {
        // Network errors - retry with exponential backoff
        recoveryStrategies["network"] = RecoveryStrategy(
            errorType: "Network Error",
            action: .retry(attempts: 3, delay: 2.0)
        ) { error in
            if case .networkError = error { return true }
            if case .timeout = error { return true }
            return false
        }
        
        // Rate limiting - wait and retry
        recoveryStrategies["rateLimit"] = RecoveryStrategy(
            errorType: "Rate Limit",
            action: .retry(attempts: 1, delay: 60.0)
        ) { error in
            if case .rateLimited = error { return true }
            return false
        }
        
        // Service unavailable - fallback
        recoveryStrategies["service"] = RecoveryStrategy(
            errorType: "Service Unavailable",
            action: .fallback(to: "cached_response")
        ) { error in
            if case .serviceUnavailable = error { return true }
            return false
        }
        
        // Invalid arguments - skip
        recoveryStrategies["arguments"] = RecoveryStrategy(
            errorType: "Invalid Arguments",
            action: .skip
        ) { error in
            if case .invalidArguments = error { return true }
            return false
        }
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: FunctionError, 
                    functionName: String,
                    context: [String: Any] = [:]) -> RecoveryAction? {
        
        // Find matching recovery strategy
        let recovery = recoveryStrategies.values.first { strategy in
            strategy.condition(error)
        }?.action
        
        // Log error
        let entry = ErrorEntry(
            timestamp: Date(),
            functionName: functionName,
            error: error,
            recovery: recovery,
            resolved: false
        )
        errorLog.append(entry)
        
        return recovery
    }
    
    @MainActor
    func executeWithErrorHandling<T>(
        functionName: String,
        execute: () async throws -> T
    ) async -> Result<T, FunctionError> {
        
        do {
            let result = try await execute()
            return .success(result)
        } catch {
            let functionError = mapToFunctionError(error)
            
            if let recovery = handleError(functionError, functionName: functionName) {
                switch recovery {
                case .retry(let attempts, let delay):
                    return await retryWithBackoff(
                        functionName: functionName,
                        attempts: attempts,
                        delay: delay,
                        execute: execute
                    )
                    
                case .fallback(let alternative):
                    // Return fallback result
                    return .failure(functionError)
                    
                case .skip:
                    return .failure(functionError)
                    
                case .abort:
                    return .failure(functionError)
                    
                case .manual:
                    return .failure(functionError)
                }
            }
            
            return .failure(functionError)
        }
    }
    
    private func retryWithBackoff<T>(
        functionName: String,
        attempts: Int,
        delay: TimeInterval,
        execute: () async throws -> T
    ) async -> Result<T, FunctionError> {
        
        var lastError: FunctionError?
        
        for attempt in 1...attempts {
            do {
                let result = try await execute()
                
                // Mark as resolved
                if let lastIndex = errorLog.lastIndex(where: { 
                    $0.functionName == functionName && !$0.resolved 
                }) {
                    errorLog[lastIndex] = ErrorEntry(
                        id: errorLog[lastIndex].id,
                        timestamp: errorLog[lastIndex].timestamp,
                        functionName: functionName,
                        error: errorLog[lastIndex].error,
                        recovery: errorLog[lastIndex].recovery,
                        resolved: true
                    )
                }
                
                return .success(result)
            } catch {
                lastError = mapToFunctionError(error)
                
                if attempt < attempts {
                    // Exponential backoff
                    let waitTime = delay * pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }
        
        return .failure(lastError ?? .unknown(NSError()))
    }
    
    private func mapToFunctionError(_ error: Error) -> FunctionError {
        // Map common errors to FunctionError cases
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout(30)
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(urlError)
            default:
                return .networkError(urlError)
            }
        }
        
        // Check for custom error types
        if let error = error as? FunctionError {
            return error
        }
        
        return .unknown(error)
    }
}

// MARK: - Error Recovery UI

struct FunctionErrorRecoveryView: View {
    @StateObject private var errorHandler = FunctionErrorHandler()
    @StateObject private var client: DeepSeekClient
    @State private var isSimulating = false
    
    init(apiKey: String) {
        _client = StateObject(wrappedValue: DeepSeekClient(apiKey: apiKey))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Error simulation controls
            ErrorSimulationPanel(
                errorHandler: errorHandler,
                isSimulating: $isSimulating
            )
            
            // Error log
            ErrorLogView(entries: errorHandler.errorLog)
            
            // Recovery strategies
            RecoveryStrategiesView(strategies: errorHandler.recoveryStrategies)
        }
        .navigationTitle("Error Handling")
    }
}

struct ErrorSimulationPanel: View {
    let errorHandler: FunctionErrorHandler
    @Binding var isSimulating: Bool
    
    let simulationScenarios = [
        ("Network Timeout", FunctionErrorHandler.FunctionError.timeout(30)),
        ("Rate Limited", FunctionErrorHandler.FunctionError.rateLimited(retryAfter: 60)),
        ("Invalid Arguments", FunctionErrorHandler.FunctionError.invalidArguments("Missing required parameter")),
        ("Service Unavailable", FunctionErrorHandler.FunctionError.serviceUnavailable),
        ("Unauthorized", FunctionErrorHandler.FunctionError.unauthorized)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Simulate Errors")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(simulationScenarios, id: \.0) { scenario in
                        Button(action: {
                            simulateError(scenario.1, functionName: scenario.0)
                        }) {
                            Text(scenario.0)
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Button(action: runFullSimulation) {
                if isSimulating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Running Simulation...")
                    }
                } else {
                    Text("Run Full Simulation")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSimulating)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func simulateError(_ error: FunctionErrorHandler.FunctionError, functionName: String) {
        _ = errorHandler.handleError(error, functionName: functionName)
    }
    
    private func runFullSimulation() {
        Task {
            await performFullSimulation()
        }
    }
    
    @MainActor
    private func performFullSimulation() async {
        isSimulating = true
        
        // Simulate various function calls with errors
        for (name, error) in simulationScenarios {
            let result = await errorHandler.executeWithErrorHandling(
                functionName: name
            ) {
                // Simulate function that always throws
                throw error
            }
            
            switch result {
            case .success:
                print("Function succeeded after recovery")
            case .failure(let error):
                print("Function failed: \(error.localizedDescription)")
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        isSimulating = false
    }
}

struct ErrorLogView: View {
    let entries: [FunctionErrorHandler.ErrorEntry]
    @State private var selectedEntry: FunctionErrorHandler.ErrorEntry?
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Error Log")
                    .font(.headline)
                
                Spacer()
                
                if !entries.isEmpty {
                    Text("\(entries.filter { !$0.resolved }.count) unresolved")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(entries.reversed()) { entry in
                        ErrorLogRow(entry: entry)
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(item: $selectedEntry) { entry in
            ErrorDetailView(entry: entry)
        }
    }
}

struct ErrorLogRow: View {
    let entry: FunctionErrorHandler.ErrorEntry
    
    var body: some View {
        HStack {
            Image(systemName: entry.error.severity.icon)
                .foregroundColor(entry.error.severity.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.functionName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(entry.error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if entry.resolved {
                    Label("Resolved", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else if let recovery = entry.recovery {
                    Text(recoveryLabel(for: recovery))
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(entry.resolved ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(6)
    }
    
    private func recoveryLabel(for action: FunctionErrorHandler.RecoveryAction) -> String {
        switch action {
        case .retry: return "Retrying..."
        case .fallback: return "Using fallback"
        case .skip: return "Skipped"
        case .abort: return "Aborted"
        case .manual: return "Manual"
        }
    }
}

struct ErrorDetailView: View {
    let entry: FunctionErrorHandler.ErrorEntry
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Error info
                VStack(alignment: .leading, spacing: 12) {
                    Label(entry.functionName, systemImage: "function")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Label("Severity", systemImage: entry.error.severity.icon)
                            .foregroundColor(entry.error.severity.color)
                        
                        Spacer()
                        
                        if entry.resolved {
                            Label("Resolved", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Unresolved", systemImage: "xmark.circle")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.subheadline)
                    
                    Text(entry.timestamp, style: .dateTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Error details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Error Details")
                        .font(.headline)
                    
                    Text(entry.error.localizedDescription)
                        .font(.body)
                    
                    if let recovery = entry.recovery {
                        Divider()
                        
                        Text("Recovery Action")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(recovery.description)
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Error Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RecoveryStrategiesView: View {
    let strategies: [String: FunctionErrorHandler.RecoveryStrategy]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recovery Strategies")
                .font(.headline)
            
            ForEach(Array(strategies.keys.sorted()), id: \.self) { key in
                if let strategy = strategies[key] {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(strategy.errorType)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(strategy.action.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: iconForAction(strategy.action))
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func iconForAction(_ action: FunctionErrorHandler.RecoveryAction) -> String {
        switch action {
        case .retry: return "arrow.clockwise"
        case .fallback: return "arrow.uturn.right"
        case .skip: return "forward"
        case .abort: return "stop.circle"
        case .manual: return "hand.raised"
        }
    }
}

// MARK: - Practical Example

struct WeatherFunctionWithErrorHandling: View {
    @StateObject private var errorHandler = FunctionErrorHandler()
    @State private var location = ""
    @State private var weather: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Weather with Error Handling")
                .font(.headline)
            
            HStack {
                TextField("Enter location", text: $location)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: fetchWeather) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Get Weather")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(location.isEmpty || isLoading)
            }
            
            if let weather = weather {
                Text(weather)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Show recent errors
            if !errorHandler.errorLog.isEmpty {
                VStack(alignment: .leading) {
                    Text("Recent Errors")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(errorHandler.errorLog.suffix(3).reversed()) { entry in
                        HStack {
                            Image(systemName: entry.error.severity.icon)
                                .foregroundColor(entry.error.severity.color)
                                .font(.caption)
                            
                            Text(entry.error.localizedDescription)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if entry.resolved {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private func fetchWeather() {
        Task {
            await performWeatherFetch()
        }
    }
    
    @MainActor
    private func performWeatherFetch() async {
        isLoading = true
        weather = nil
        
        let result = await errorHandler.executeWithErrorHandling(
            functionName: "get_weather"
        ) {
            // Simulate various error conditions
            if location.lowercased() == "timeout" {
                throw FunctionErrorHandler.FunctionError.timeout(5)
            }
            
            if location.lowercased() == "error" {
                throw FunctionErrorHandler.FunctionError.serviceUnavailable
            }
            
            if location.count < 3 {
                throw FunctionErrorHandler.FunctionError.invalidArguments("Location too short")
            }
            
            // Simulate API call
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            return "Weather for \(location): 72°F, Sunny"
        }
        
        switch result {
        case .success(let weatherData):
            weather = weatherData
        case .failure(let error):
            weather = "Failed to get weather: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}