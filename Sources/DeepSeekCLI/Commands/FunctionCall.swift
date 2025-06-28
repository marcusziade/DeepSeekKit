import ArgumentParser
import DeepSeekKit
import Foundation

struct FunctionCall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Test function calling capabilities"
    )
    
    @OptionGroup var common: CommonOptions
    
    @Argument(help: "The message that should trigger function calls")
    var message: String
    
    @Option(name: .shortAndLong, help: "Model to use (chat or reasoner)")
    var model: String = "chat"
    
    @Flag(name: .long, help: "Use auto tool choice")
    var auto = false
    
    @Flag(name: .long, help: "Force function call")
    var force = false
    
    mutating func run() async throws {
        let client = try common.getClient()
        
        let modelType: DeepSeekModel = model == "reasoner" ? .reasoner : .chat
        
        // Define example functions
        let weatherFunction = FunctionBuilder(
            name: "get_weather",
            description: "Get the current weather in a given location"
        )
        .addStringParameter("location", description: "The city and state, e.g. San Francisco, CA", required: true)
        .addStringParameter("unit", description: "Temperature unit (celsius or fahrenheit)", required: false)
        .buildTool()
        
        let calculateFunction = FunctionBuilder(
            name: "calculate",
            description: "Perform mathematical calculations"
        )
        .addStringParameter("expression", description: "The mathematical expression to evaluate", required: true)
        .buildTool()
        
        let searchFunction = FunctionBuilder(
            name: "search_web",
            description: "Search the web for information"
        )
        .addStringParameter("query", description: "The search query", required: true)
        .addNumberParameter("max_results", description: "Maximum number of results to return", required: false)
        .buildTool()
        
        let tools = [weatherFunction, calculateFunction, searchFunction]
        
        var toolChoice: ToolChoice = .none
        if auto {
            toolChoice = .auto
        } else if force {
            toolChoice = .required
        }
        
        let request = ChatCompletionRequest(
            model: modelType,
            messages: [.user(message)],
            tools: tools,
            toolChoice: toolChoice
        )
        
        print("Testing function calling with \(modelType.rawValue)...")
        print("Available functions: get_weather, calculate, search_web")
        print("Tool choice: \(auto ? "auto" : (force ? "required" : "none"))\n")
        
        do {
            let response = try await client.chat.createCompletion(request)
            
            if let toolCalls = response.choices.first?.message.toolCalls, !toolCalls.isEmpty {
                print("Function calls made:")
                for call in toolCalls {
                    print("\n• Function: \(call.function.name)")
                    print("  ID: \(call.id)")
                    print("  Arguments: \(call.function.arguments)")
                    
                    // Simulate function execution
                    let result = simulateFunctionCall(
                        name: call.function.name,
                        arguments: call.function.arguments
                    )
                    print("  Simulated result: \(result)")
                }
                
                // Continue conversation with function results
                print("\nContinuing conversation with function results...")
                
                var messages = request.messages
                messages.append(response.choices.first!.message.toMessage())
                
                for call in toolCalls {
                    let result = simulateFunctionCall(
                        name: call.function.name,
                        arguments: call.function.arguments
                    )
                    messages.append(.tool(
                        content: result,
                        toolCallId: call.id,
                        name: call.function.name
                    ))
                }
                
                let followUpRequest = ChatCompletionRequest(
                    model: modelType,
                    messages: messages
                )
                
                let followUpResponse = try await client.chat.createCompletion(followUpRequest)
                
                if let content = followUpResponse.choices.first?.message.content {
                    print("\nFinal response:")
                    print(content)
                }
            } else if let content = response.choices.first?.message.content {
                print("Response (no function calls):")
                print(content)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    func simulateFunctionCall(name: String, arguments: String) -> String {
        switch name {
        case "get_weather":
            return "{\"temperature\": 72, \"condition\": \"sunny\", \"humidity\": 45}"
        case "calculate":
            return "{\"result\": 42}"
        case "search_web":
            return "{\"results\": [{\"title\": \"Example Result\", \"url\": \"https://example.com\"}]}"
        default:
            return "{\"error\": \"Unknown function\"}"
        }
    }
}

// Extension to convert ResponseMessage to ChatMessage
extension ResponseMessage {
    func toMessage() -> ChatMessage {
        ChatMessage(
            role: role,
            content: content ?? "",
            toolCalls: toolCalls
        )
    }
}