import ArgumentParser
import DeepSeekKit
import Foundation

struct Complete: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a completion using Fill-in-Middle (FIM) mode (Beta)"
    )
    
    @OptionGroup var common: CommonOptions
    
    @Argument(help: "The prompt text")
    var prompt: String
    
    @Option(name: .shortAndLong, help: "Text after the completion")
    var suffix: String?
    
    @Option(name: .shortAndLong, help: "Temperature (0-2)")
    var temperature: Double?
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int?
    
    @Flag(name: .long, help: "Show usage statistics")
    var showUsage = false
    
    mutating func run() async throws {
        let client = try common.getClient()
        
        let request = CompletionRequest(
            model: .chat,
            prompt: prompt,
            suffix: suffix,
            maxTokens: maxTokens,
            temperature: temperature
        )
        
        print("Creating completion (FIM mode)...\n")
        
        if let suffix = suffix {
            print("Prefix: \(prompt)")
            print("Suffix: \(suffix)")
            print("\nCompletion:")
        } else {
            print("Prompt: \(prompt)")
            print("\nCompletion:")
        }
        
        do {
            let response = try await client.chat.createCompletion(request)
            
            if let text = response.choices.first?.text {
                print(text)
            }
            
            if showUsage {
                print("\nUsage:")
                print("  Prompt tokens: \(response.usage.promptTokens)")
                print("  Completion tokens: \(response.usage.completionTokens)")
                print("  Total tokens: \(response.usage.totalTokens)")
            }
        } catch {
            print("\nError: \(error.localizedDescription)")
            print("Note: FIM completion is a beta feature and requires access.")
            throw ExitCode.failure
        }
    }
}