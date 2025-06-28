import DeepSeekKit
import Foundation

// Example demonstrating basic usage of DeepSeekKit

@main
struct BasicUsageExample {
    static func main() async throws {
        // Initialize client with API key
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] else {
            print("Please set DEEPSEEK_API_KEY environment variable")
            exit(1)
        }
        
        let client = DeepSeekClient(apiKey: apiKey)
        
        // Example 1: Simple chat completion
        print("=== Simple Chat Completion ===")
        let chatResponse = try await client.chat.createCompletion(
            ChatCompletionRequest(
                model: .chat,
                messages: [
                    .system("You are a helpful assistant"),
                    .user("What is the capital of France?")
                ]
            )
        )
        print(chatResponse.choices.first?.message.content ?? "")
        
        // Example 2: Function calling
        print("\n=== Function Calling ===")
        let weatherTool = FunctionBuilder(
            name: "get_weather",
            description: "Get the current weather"
        )
        .addStringParameter("location", description: "City name", required: true)
        .buildTool()
        
        let functionResponse = try await client.chat.createCompletion(
            ChatCompletionRequest(
                model: .chat,
                messages: [.user("What's the weather in London?")],
                tools: [weatherTool],
                toolChoice: .auto
            )
        )
        
        if let toolCalls = functionResponse.choices.first?.message.toolCalls {
            for call in toolCalls {
                print("Function called: \(call.function.name)")
                print("Arguments: \(call.function.arguments)")
            }
        }
        
        // Example 3: JSON mode
        print("\n=== JSON Mode ===")
        let jsonResponse = try await client.chat.createCompletion(
            ChatCompletionRequest(
                model: .chat,
                messages: [.user("Generate a user profile with name, age, and city in JSON format")],
                responseFormat: ResponseFormat(type: .jsonObject)
            )
        )
        print(jsonResponse.choices.first?.message.content ?? "")
        
        // Example 4: List models
        print("\n=== Available Models ===")
        let models = try await client.models.listModels()
        for model in models {
            print("- \(model.id)")
        }
        
        // Example 5: Check balance
        print("\n=== Account Balance ===")
        let balance = try await client.balance.getBalance()
        for bal in balance.balances {
            print("\(bal.currency): \(bal.totalBalance)")
        }
    }
}