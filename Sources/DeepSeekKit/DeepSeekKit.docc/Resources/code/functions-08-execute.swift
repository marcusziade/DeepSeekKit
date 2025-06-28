import SwiftUI
import DeepSeekKit

// Execute function calls and return results
class FunctionExecutor: ObservableObject {
    @Published var executionLog: [ExecutionEntry] = []
    @Published var isExecuting = false
    
    struct ExecutionEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let functionName: String
        let arguments: [String: Any]
        let result: Result<String, Error>
        let duration: TimeInterval
        
        var status: Status {
            switch result {
            case .success: return .success
            case .failure: return .failure
            }
        }
        
        enum Status {
            case success
            case failure
            
            var color: Color {
                switch self {
                case .success: return .green
                case .failure: return .red
                }
            }
            
            var icon: String {
                switch self {
                case .success: return "checkmark.circle.fill"
                case .failure: return "xmark.circle.fill"
                }
            }
        }
    }
    
    // MARK: - Function Registry
    
    private var functionRegistry: [String: FunctionHandler] = [:]
    
    typealias FunctionHandler = (Arguments) async throws -> String
    
    struct Arguments {
        private let data: [String: Any]
        
        init(_ data: [String: Any]) {
            self.data = data
        }
        
        func get<T>(_ key: String) -> T? {
            data[key] as? T
        }
        
        func require<T>(_ key: String) throws -> T {
            guard let value = data[key] as? T else {
                throw FunctionError.missingRequiredParameter(key)
            }
            return value
        }
        
        func get<T>(_ key: String, default defaultValue: T) -> T {
            data[key] as? T ?? defaultValue
        }
    }
    
    enum FunctionError: LocalizedError {
        case unknownFunction(String)
        case missingRequiredParameter(String)
        case invalidParameterType(String, expected: String)
        case executionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .unknownFunction(let name):
                return "Unknown function: \(name)"
            case .missingRequiredParameter(let param):
                return "Missing required parameter: \(param)"
            case .invalidParameterType(let param, let expected):
                return "Invalid type for parameter '\(param)', expected: \(expected)"
            case .executionFailed(let reason):
                return "Function execution failed: \(reason)"
            }
        }
    }
    
    init() {
        registerBuiltInFunctions()
    }
    
    // MARK: - Function Registration
    
    func register(_ name: String, handler: @escaping FunctionHandler) {
        functionRegistry[name] = handler
    }
    
    private func registerBuiltInFunctions() {
        // Math functions
        register("calculate") { args in
            try await self.executeCalculation(args)
        }
        
        // String manipulation
        register("string_transform") { args in
            try await self.executeStringTransform(args)
        }
        
        // Data processing
        register("process_data") { args in
            try await self.executeDataProcessing(args)
        }
        
        // File operations
        register("file_operation") { args in
            try await self.executeFileOperation(args)
        }
        
        // Network requests
        register("http_request") { args in
            try await self.executeHTTPRequest(args)
        }
    }
    
    // MARK: - Execution
    
    @MainActor
    func execute(toolCall: ChatCompletionResponse.Choice.Message.ToolCall) async -> Message {
        let startTime = Date()
        isExecuting = true
        
        // Parse arguments
        let arguments: [String: Any]
        do {
            guard let data = toolCall.function.arguments.data(using: .utf8) else {
                throw FunctionError.executionFailed("Invalid arguments encoding")
            }
            
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FunctionError.executionFailed("Arguments must be a JSON object")
            }
            
            arguments = parsed
        } catch {
            let entry = ExecutionEntry(
                timestamp: startTime,
                functionName: toolCall.function.name,
                arguments: [:],
                result: .failure(error),
                duration: Date().timeIntervalSince(startTime)
            )
            executionLog.append(entry)
            isExecuting = false
            
            return Message(
                role: .function,
                content: formatError(error),
                name: toolCall.function.name,
                toolCallId: toolCall.id
            )
        }
        
        // Execute function
        let result: Result<String, Error>
        
        if let handler = functionRegistry[toolCall.function.name] {
            do {
                let output = try await handler(Arguments(arguments))
                result = .success(output)
            } catch {
                result = .failure(error)
            }
        } else {
            result = .failure(FunctionError.unknownFunction(toolCall.function.name))
        }
        
        // Log execution
        let entry = ExecutionEntry(
            timestamp: startTime,
            functionName: toolCall.function.name,
            arguments: arguments,
            result: result,
            duration: Date().timeIntervalSince(startTime)
        )
        executionLog.append(entry)
        isExecuting = false
        
        // Return function message
        return Message(
            role: .function,
            content: formatResult(result),
            name: toolCall.function.name,
            toolCallId: toolCall.id
        )
    }
    
    private func formatResult(_ result: Result<String, Error>) -> String {
        switch result {
        case .success(let output):
            return output
        case .failure(let error):
            return formatError(error)
        }
    }
    
    private func formatError(_ error: Error) -> String {
        """
        {
            "error": true,
            "message": "\(error.localizedDescription)"
        }
        """
    }
    
    // MARK: - Built-in Function Implementations
    
    private func executeCalculation(_ args: Arguments) async throws -> String {
        if let expression = args.get("expression") as String? {
            // Use NSExpression for safe calculation
            let mathExpression = NSExpression(format: expression)
            
            guard let result = mathExpression.expressionValue(with: nil, context: nil) else {
                throw FunctionError.executionFailed("Invalid expression")
            }
            
            return """
            {
                "expression": "\(expression)",
                "result": \(result)
            }
            """
        }
        
        // Alternative: Use operation and operands
        let operation: String = try args.require("operation")
        let operands: [Double] = try args.require("operands")
        
        guard operands.count >= 2 else {
            throw FunctionError.executionFailed("At least 2 operands required")
        }
        
        let result: Double
        
        switch operation {
        case "add":
            result = operands.reduce(0, +)
        case "subtract":
            result = operands[0] - operands.dropFirst().reduce(0, +)
        case "multiply":
            result = operands.reduce(1, *)
        case "divide":
            guard !operands.dropFirst().contains(0) else {
                throw FunctionError.executionFailed("Division by zero")
            }
            result = operands.dropFirst().reduce(operands[0]) { $0 / $1 }
        case "power":
            result = pow(operands[0], operands[1])
        case "sqrt":
            guard operands[0] >= 0 else {
                throw FunctionError.executionFailed("Cannot take square root of negative number")
            }
            result = sqrt(operands[0])
        default:
            throw FunctionError.executionFailed("Unknown operation: \(operation)")
        }
        
        return """
        {
            "operation": "\(operation)",
            "operands": \(operands),
            "result": \(result)
        }
        """
    }
    
    private func executeStringTransform(_ args: Arguments) async throws -> String {
        let text: String = try args.require("text")
        let operation: String = try args.require("operation")
        
        let result: String
        
        switch operation {
        case "uppercase":
            result = text.uppercased()
        case "lowercase":
            result = text.lowercased()
        case "capitalize":
            result = text.capitalized
        case "reverse":
            result = String(text.reversed())
        case "trim":
            result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case "word_count":
            let wordCount = text.split(separator: " ").count
            return """
            {
                "text": "\(text)",
                "word_count": \(wordCount)
            }
            """
        case "replace":
            let find: String = try args.require("find")
            let replace: String = try args.require("replace")
            result = text.replacingOccurrences(of: find, with: replace)
        default:
            throw FunctionError.executionFailed("Unknown string operation: \(operation)")
        }
        
        return """
        {
            "original": "\(text)",
            "operation": "\(operation)",
            "result": "\(result)"
        }
        """
    }
    
    private func executeDataProcessing(_ args: Arguments) async throws -> String {
        let data: [Double] = try args.require("data")
        let operation: String = try args.require("operation")
        
        guard !data.isEmpty else {
            throw FunctionError.executionFailed("Data array is empty")
        }
        
        switch operation {
        case "statistics":
            let mean = data.reduce(0, +) / Double(data.count)
            let sorted = data.sorted()
            let median = sorted.count % 2 == 0 ?
                (sorted[sorted.count/2 - 1] + sorted[sorted.count/2]) / 2 :
                sorted[sorted.count/2]
            let min = sorted.first!
            let max = sorted.last!
            
            // Calculate standard deviation
            let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(data.count)
            let stdDev = sqrt(variance)
            
            return """
            {
                "count": \(data.count),
                "mean": \(mean),
                "median": \(median),
                "min": \(min),
                "max": \(max),
                "std_dev": \(stdDev)
            }
            """
            
        case "filter":
            let condition: String = try args.require("condition")
            let threshold: Double = args.get("threshold", default: 0.0)
            
            let filtered: [Double]
            switch condition {
            case "greater_than":
                filtered = data.filter { $0 > threshold }
            case "less_than":
                filtered = data.filter { $0 < threshold }
            case "equal_to":
                filtered = data.filter { $0 == threshold }
            default:
                throw FunctionError.executionFailed("Unknown filter condition: \(condition)")
            }
            
            return """
            {
                "original_count": \(data.count),
                "filtered_count": \(filtered.count),
                "filtered_data": \(filtered)
            }
            """
            
        default:
            throw FunctionError.executionFailed("Unknown data operation: \(operation)")
        }
    }
    
    private func executeFileOperation(_ args: Arguments) async throws -> String {
        // Simulate file operations (in a real app, implement actual file handling)
        let operation: String = try args.require("operation")
        let path: String = try args.require("path")
        
        // Simulate delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        switch operation {
        case "read":
            return """
            {
                "path": "\(path)",
                "content": "This is simulated file content",
                "size": 1024,
                "modified": "\(ISO8601DateFormatter().string(from: Date()))"
            }
            """
            
        case "write":
            let content: String = try args.require("content")
            return """
            {
                "path": "\(path)",
                "bytes_written": \(content.count),
                "success": true
            }
            """
            
        case "list":
            return """
            {
                "path": "\(path)",
                "files": ["file1.txt", "file2.json", "folder/"],
                "count": 3
            }
            """
            
        default:
            throw FunctionError.executionFailed("Unknown file operation: \(operation)")
        }
    }
    
    private func executeHTTPRequest(_ args: Arguments) async throws -> String {
        let url: String = try args.require("url")
        let method: String = args.get("method", default: "GET")
        
        // Simulate HTTP request
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return """
        {
            "url": "\(url)",
            "method": "\(method)",
            "status": 200,
            "headers": {
                "content-type": "application/json",
                "content-length": "256"
            },
            "body": {
                "message": "Simulated response",
                "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
            }
        }
        """
    }
}

// MARK: - Execution View

struct FunctionExecutorView: View {
    @StateObject private var executor = FunctionExecutor()
    @StateObject private var client: DeepSeekClient
    @State private var inputText = ""
    @State private var messages: [Message] = []
    @State private var isProcessing = false
    
    init(apiKey: String) {
        _client = StateObject(wrappedValue: DeepSeekClient(apiKey: apiKey))
    }
    
    var body: some View {
        VStack {
            // Execution log
            ExecutionLogView(entries: executor.executionLog)
            
            Divider()
            
            // Chat interface
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                        MessageRow(message: message)
                    }
                }
                .padding()
            }
            
            // Input
            HStack {
                TextField("Ask to execute a function...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding()
        }
        .navigationTitle("Function Executor")
        .onAppear {
            setupSystemMessage()
        }
    }
    
    private func setupSystemMessage() {
        messages = [
            Message(
                role: .system,
                content: """
                You have access to various functions for calculations, 
                string manipulation, data processing, file operations, 
                and HTTP requests. Use them to help the user.
                """
            )
        ]
    }
    
    private func sendMessage() {
        let userMessage = Message(role: .user, content: inputText)
        messages.append(userMessage)
        inputText = ""
        
        Task {
            await processWithFunctions()
        }
    }
    
    @MainActor
    private func processWithFunctions() async {
        isProcessing = true
        
        do {
            // Create function tools
            let tools = createDemoTools()
            
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: messages,
                tools: tools
            )
            
            let response = try await client.chat.completions(request)
            
            if let message = response.choices.first?.message {
                if let toolCalls = message.toolCalls {
                    // Execute each function call
                    for toolCall in toolCalls {
                        let functionMessage = await executor.execute(toolCall: toolCall)
                        messages.append(functionMessage)
                    }
                    
                    // Get final response
                    let finalRequest = ChatCompletionRequest(
                        model: .deepSeekChat,
                        messages: messages
                    )
                    
                    let finalResponse = try await client.chat.completions(finalRequest)
                    if let finalMessage = finalResponse.choices.first?.message {
                        messages.append(finalMessage)
                    }
                } else {
                    messages.append(message)
                }
            }
        } catch {
            messages.append(Message(
                role: .assistant,
                content: "Error: \(error.localizedDescription)"
            ))
        }
        
        isProcessing = false
    }
    
    private func createDemoTools() -> [ChatCompletionRequest.Tool] {
        [
            FunctionBuilder()
                .withName("calculate")
                .withDescription("Perform mathematical calculations")
                .addParameter("expression", type: .string, description: "Math expression to evaluate")
                .addParameter("operation", type: .string, description: "Operation type", enumValues: ["add", "subtract", "multiply", "divide", "power", "sqrt"])
                .addArrayParameter("operands", itemType: .number, description: "Numbers to operate on")
                .build(),
            
            FunctionBuilder()
                .withName("string_transform")
                .withDescription("Transform text strings")
                .addParameter("text", type: .string, description: "Text to transform", required: true)
                .addParameter("operation", type: .string, description: "Transformation to apply", required: true, enumValues: ["uppercase", "lowercase", "capitalize", "reverse", "trim", "word_count", "replace"])
                .addParameter("find", type: .string, description: "Text to find (for replace)")
                .addParameter("replace", type: .string, description: "Replacement text")
                .build(),
            
            FunctionBuilder()
                .withName("process_data")
                .withDescription("Process numerical data")
                .addArrayParameter("data", itemType: .number, description: "Array of numbers", required: true)
                .addParameter("operation", type: .string, description: "Processing operation", required: true, enumValues: ["statistics", "filter"])
                .addParameter("condition", type: .string, description: "Filter condition", enumValues: ["greater_than", "less_than", "equal_to"])
                .addParameter("threshold", type: .number, description: "Threshold value for filtering")
                .build()
        ]
    }
}

struct ExecutionLogView: View {
    let entries: [FunctionExecutor.ExecutionEntry]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Execution Log")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(entries) { entry in
                        ExecutionEntryRow(entry: entry)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 150)
        }
        .background(Color(.systemGray6))
    }
}

struct ExecutionEntryRow: View {
    let entry: FunctionExecutor.ExecutionEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.status.icon)
                    .foregroundColor(entry.status.color)
                    .font(.caption)
                
                Text(entry.functionName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("(\(Int(entry.duration * 1000))ms)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    
                    Text(formatJSON(entry.arguments))
                        .font(.caption2)
                        .padding(4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    switch entry.result {
                    case .success(let output):
                        Text("Result:")
                            .font(.caption2)
                            .fontWeight(.semibold)
                        
                        Text(output)
                            .font(.caption2)
                            .padding(4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                        
                    case .failure(let error):
                        Text("Error: \(error.localizedDescription)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatJSON(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return String(describing: object)
        }
        return string
    }
}

struct MessageRow: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: iconForRole(message.role))
                .font(.caption)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message.role.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .font(.body)
            }
            
            Spacer()
        }
    }
    
    private func iconForRole(_ role: MessageRole) -> String {
        switch role {
        case .system: return "gear"
        case .user: return "person.fill"
        case .assistant: return "cpu"
        case .function: return "function"
        }
    }
}