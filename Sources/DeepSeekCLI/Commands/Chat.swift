import ArgumentParser
import DeepSeekKit
import Foundation

struct Chat: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Send a chat completion request"
    )
    
    @OptionGroup var common: CommonOptions
    
    @Argument(help: "The message to send")
    var message: String
    
    @Option(name: .shortAndLong, help: "System prompt")
    var system: String?
    
    @Option(name: .shortAndLong, help: "Model to use (chat or reasoner)")
    var model: String = "chat"
    
    @Option(name: .shortAndLong, help: "Temperature (0-2)")
    var temperature: Double?
    
    @Option(name: .long, help: "Top-p value (0-1)")
    var topP: Double?
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int?
    
    @Option(name: .long, help: "Frequency penalty (-2 to 2)")
    var frequencyPenalty: Double?
    
    @Option(name: .long, help: "Presence penalty (-2 to 2)")
    var presencePenalty: Double?
    
    @Flag(name: .long, help: "Show usage statistics")
    var showUsage = false
    
    mutating func run() async throws {
        let client = try common.getClient()
        
        let modelType: DeepSeekModel = model == "reasoner" ? .reasoner : .chat
        
        var messages: [ChatMessage] = []
        if let system = system {
            messages.append(.system(system))
        }
        messages.append(.user(message))
        
        let request = ChatCompletionRequest(
            model: modelType,
            messages: messages,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty
        )
        
        print("Sending request to \(modelType.rawValue)...\n")
        
        do {
            let response = try await client.chat.createCompletion(request)
            
            if let content = response.choices.first?.message.content {
                print("Response:")
                print(content)
            }
            
            if let reasoningContent = response.choices.first?.message.reasoningContent {
                print("\n--- Reasoning Process ---")
                print(reasoningContent)
                print("--- End Reasoning ---\n")
            }
            
            if showUsage {
                print("\nUsage:")
                print("  Prompt tokens: \(response.usage.promptTokens)")
                print("  Completion tokens: \(response.usage.completionTokens)")
                print("  Total tokens: \(response.usage.totalTokens)")
                if let cacheHit = response.usage.promptCacheHitTokens {
                    print("  Cache hit tokens: \(cacheHit)")
                }
                if let cacheMiss = response.usage.promptCacheMissTokens {
                    print("  Cache miss tokens: \(cacheMiss)")
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}