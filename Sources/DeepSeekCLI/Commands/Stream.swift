import ArgumentParser
import DeepSeekKit
import Foundation

struct Stream: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stream a chat completion response"
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
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int?
    
    @Flag(name: .long, help: "Show reasoning content separately")
    var showReasoning = false
    
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
            maxTokens: maxTokens,
            stream: true
        )
        
        print("Streaming response from \(modelType.rawValue)...\n")
        
        var responseContent = ""
        var reasoningContent = ""
        var usage: Usage?
        
        do {
            for try await chunk in client.chat.createStreamingCompletion(request) {
                if let delta = chunk.choices.first?.delta {
                    if let content = delta.content {
                        responseContent += content
                        print(content, terminator: "")
                        fflush(stdout)
                    }
                    
                    if let reasoning = delta.reasoningContent {
                        reasoningContent += reasoning
                        if showReasoning {
                            print("[R: \(reasoning)]", terminator: "")
                            fflush(stdout)
                        }
                    }
                }
                
                if let chunkUsage = chunk.usage {
                    usage = chunkUsage
                }
            }
            
            print("\n")
            
            if showReasoning && !reasoningContent.isEmpty {
                print("\n--- Reasoning Process ---")
                print(reasoningContent)
                print("--- End Reasoning ---\n")
            }
            
            if let usage = usage {
                print("\nUsage:")
                print("  Prompt tokens: \(usage.promptTokens)")
                print("  Completion tokens: \(usage.completionTokens)")
                print("  Total tokens: \(usage.totalTokens)")
            }
        } catch {
            print("\nError: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}