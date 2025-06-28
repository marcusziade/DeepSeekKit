import SwiftUI
import DeepSeekKit

// Handle function call responses
class FunctionCallHandler: ObservableObject {
    @Published var messages: [Message] = []
    @Published var pendingFunctionCalls: [ChatCompletionResponse.Choice.Message.ToolCall] = []
    @Published var functionResults: [String: Any] = [:]
    
    private let client: DeepSeekClient
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
    }
    
    // MARK: - Function Call Processing
    
    func processResponse(_ response: ChatCompletionResponse) async throws {
        guard let message = response.choices.first?.message else { return }
        
        // Check if AI wants to call functions
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            pendingFunctionCalls = toolCalls
            
            // Process each function call
            for toolCall in toolCalls {
                await processFunctionCall(toolCall)
            }
            
            // Continue conversation with function results
            try await continueWithFunctionResults()
        } else {
            // Regular message response
            messages.append(message)
        }
    }
    
    private func processFunctionCall(_ toolCall: ChatCompletionResponse.Choice.Message.ToolCall) async {
        let functionName = toolCall.function.name
        let arguments = toolCall.function.arguments
        
        // Parse arguments
        guard let argumentData = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argumentData) as? [String: Any] else {
            print("Failed to parse arguments for \(functionName)")
            return
        }
        
        // Execute function based on name
        let result = await executeFunction(name: functionName, arguments: args)
        
        // Store result with tool call ID
        functionResults[toolCall.id] = result
    }
    
    private func executeFunction(name: String, arguments: [String: Any]) async -> String {
        // This is where you implement your actual function logic
        switch name {
        case "get_weather":
            return await getWeather(arguments: arguments)
        case "calculate":
            return calculate(arguments: arguments)
        case "search_web":
            return await searchWeb(arguments: arguments)
        case "send_email":
            return sendEmail(arguments: arguments)
        default:
            return "Error: Unknown function '\(name)'"
        }
    }
    
    // MARK: - Example Function Implementations
    
    private func getWeather(arguments: [String: Any]) async -> String {
        guard let location = arguments["location"] as? String else {
            return "Error: Missing location parameter"
        }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mock weather data
        let weatherData = [
            "San Francisco": "72°F, Partly cloudy",
            "New York": "68°F, Clear skies",
            "London": "59°F, Light rain",
            "Tokyo": "77°F, Humid"
        ]
        
        return weatherData[location] ?? "Weather data not available for \(location)"
    }
    
    private func calculate(arguments: [String: Any]) -> String {
        if let expression = arguments["expression"] as? String {
            // Simple expression evaluation
            let expression = NSExpression(format: expression)
            if let result = expression.expressionValue(with: nil, context: nil) {
                return "Result: \(result)"
            }
        }
        
        if let operation = arguments["operation"] as? String,
           let operands = arguments["operands"] as? [Double] {
            guard operands.count >= 2 else {
                return "Error: Need at least 2 operands"
            }
            
            var result: Double
            switch operation {
            case "add":
                result = operands.reduce(0, +)
            case "subtract":
                result = operands[0] - operands[1]
            case "multiply":
                result = operands.reduce(1, *)
            case "divide":
                guard operands[1] != 0 else {
                    return "Error: Division by zero"
                }
                result = operands[0] / operands[1]
            default:
                return "Error: Unknown operation '\(operation)'"
            }
            
            return "Result: \(result)"
        }
        
        return "Error: Invalid calculation parameters"
    }
    
    private func searchWeb(arguments: [String: Any]) async -> String {
        guard let query = arguments["query"] as? String else {
            return "Error: Missing search query"
        }
        
        let maxResults = arguments["max_results"] as? Int ?? 5
        
        // Simulate search
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Mock search results
        let results = """
        Search results for "\(query)":
        1. Wikipedia: \(query) - Comprehensive overview
        2. News: Latest updates about \(query)
        3. Tutorial: How to understand \(query)
        4. Video: \(query) explained in 5 minutes
        5. Research: Academic papers on \(query)
        """
        
        return String(results.split(separator: "\n").prefix(maxResults).joined(separator: "\n"))
    }
    
    private func sendEmail(arguments: [String: Any]) -> String {
        guard let to = arguments["to"] as? String,
              let subject = arguments["subject"] as? String,
              let body = arguments["body"] as? String else {
            return "Error: Missing required email parameters"
        }
        
        let priority = arguments["priority"] as? String ?? "normal"
        let attachments = arguments["attachments"] as? [String] ?? []
        
        // Simulate email sending
        return """
        Email sent successfully!
        To: \(to)
        Subject: \(subject)
        Priority: \(priority)
        Attachments: \(attachments.count) file(s)
        """
    }
    
    // MARK: - Continue Conversation
    
    private func continueWithFunctionResults() async throws {
        // Add function results to messages
        for toolCall in pendingFunctionCalls {
            if let result = functionResults[toolCall.id] {
                let functionMessage = Message(
                    role: .function,
                    content: String(describing: result),
                    name: toolCall.function.name,
                    toolCallId: toolCall.id
                )
                messages.append(functionMessage)
            }
        }
        
        // Clear pending calls
        pendingFunctionCalls.removeAll()
        functionResults.removeAll()
        
        // Continue conversation
        let request = ChatCompletionRequest(
            model: .deepSeekChat,
            messages: messages
        )
        
        let response = try await client.chat.completions(request)
        if let assistantMessage = response.choices.first?.message {
            messages.append(assistantMessage)
        }
    }
}

// MARK: - UI Components

struct FunctionCallResponseView: View {
    @StateObject private var handler: FunctionCallHandler
    @State private var userInput = ""
    @State private var isProcessing = false
    
    let tools: [ChatCompletionRequest.Tool]
    
    init(apiKey: String, tools: [ChatCompletionRequest.Tool]) {
        self.tools = tools
        _handler = StateObject(wrappedValue: FunctionCallHandler(apiKey: apiKey))
    }
    
    var body: some View {
        VStack {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(handler.messages.enumerated()), id: \.offset) { _, message in
                            MessageView(message: message)
                        }
                        
                        // Pending function calls
                        ForEach(handler.pendingFunctionCalls, id: \.id) { toolCall in
                            FunctionCallView(toolCall: toolCall)
                        }
                    }
                    .padding()
                }
                .onChange(of: handler.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(handler.messages.count - 1, anchor: .bottom)
                    }
                }
            }
            
            // Input
            HStack {
                TextField("Type a message...", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isProcessing)
                
                Button(action: sendMessage) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(userInput.isEmpty || isProcessing)
            }
            .padding()
        }
        .navigationTitle("Function Calls")
    }
    
    private func sendMessage() {
        let message = userInput
        userInput = ""
        
        handler.messages.append(Message(role: .user, content: message))
        
        Task {
            await processMessage()
        }
    }
    
    @MainActor
    private func processMessage() async {
        isProcessing = true
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: handler.messages,
                tools: tools
            )
            
            let response = try await handler.client.chat.completions(request)
            try await handler.processResponse(response)
        } catch {
            print("Error: \(error)")
        }
        
        isProcessing = false
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconForRole(message.role))
                    .font(.caption)
                
                Text(message.role.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                if let name = message.name {
                    Text("(\(name))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.secondary)
            
            Text(message.content)
                .padding()
                .background(backgroundForRole(message.role))
                .cornerRadius(8)
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
    
    private func backgroundForRole(_ role: MessageRole) -> Color {
        switch role {
        case .system: return Color.orange.opacity(0.1)
        case .user: return Color.blue.opacity(0.1)
        case .assistant: return Color.green.opacity(0.1)
        case .function: return Color.purple.opacity(0.1)
        }
    }
}

struct FunctionCallView: View {
    let toolCall: ChatCompletionResponse.Choice.Message.ToolCall
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "function")
                    .font(.caption)
                
                Text("Calling function: \(toolCall.function.name)")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                ProgressView()
                    .scaleEffect(0.7)
            }
            .foregroundColor(.orange)
            
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text("Arguments")
                        .font(.caption)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            if isExpanded {
                Text(formatJSON(toolCall.function.arguments))
                    .font(.caption)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let string = String(data: formatted, encoding: .utf8) else {
            return json
        }
        return string
    }
}

// MARK: - Demo

struct FunctionResponseDemo: View {
    let apiKey: String
    
    let demoTools = [
        FunctionBuilder()
            .withName("get_weather")
            .withDescription("Get current weather in a location")
            .addParameter("location", type: .string, description: "City and state", required: true)
            .build(),
        
        FunctionBuilder()
            .withName("calculate")
            .withDescription("Perform calculations")
            .addParameter("expression", type: .string, description: "Math expression", required: true)
            .build()
    ]
    
    var body: some View {
        FunctionCallResponseView(apiKey: apiKey, tools: demoTools)
    }
}