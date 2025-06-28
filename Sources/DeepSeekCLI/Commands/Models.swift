import ArgumentParser
import DeepSeekKit
import Foundation

struct Models: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List available models"
    )
    
    @OptionGroup var common: CommonOptions
    
    @Flag(name: .shortAndLong, help: "Show detailed information")
    var verbose = false
    
    mutating func run() async throws {
        let client = try common.getClient()
        
        print("Fetching available models...\n")
        
        do {
            let models = try await client.models.listModels()
            
            if models.isEmpty {
                print("No models available")
                return
            }
            
            print("Available Models:")
            print("-" * 60)
            
            for model in models {
                print("\n• \(model.id)")
                if verbose {
                    print("  Type: \(model.object)")
                    print("  Owned by: \(model.ownedBy)")
                    if let created = model.created {
                        let date = Date(timeIntervalSince1970: TimeInterval(created))
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        print("  Created: \(formatter.string(from: date))")
                    }
                    
                    // Add known model capabilities
                    if model.id == "deepseek-chat" {
                        print("  Features: chat, function calling, JSON mode, streaming, FIM")
                        print("  Context: 65,536 tokens")
                        print("  Max output: 8,192 tokens")
                    } else if model.id == "deepseek-reasoner" {
                        print("  Features: chat, reasoning, function calling, JSON mode, streaming")
                        print("  Context: 65,536 tokens")
                        print("  Max output: 65,536 tokens")
                        print("  Note: No temperature/top_p/penalty controls")
                    }
                }
            }
            
            print("\n" + "-" * 60)
            print("Total models: \(models.count)")
        } catch {
            print("Note: The models endpoint may not be available yet.")
            print("\nKnown DeepSeek models:")
            print("-" * 60)
            print("\n• deepseek-chat")
            print("  - General purpose chat model")
            print("  - Features: chat, function calling, JSON mode, streaming, FIM")
            print("  - Context: 65,536 tokens")
            print("  - Max output: 8,192 tokens")
            
            print("\n• deepseek-reasoner")
            print("  - Advanced reasoning model with Chain of Thought")
            print("  - Features: chat, reasoning, function calling, JSON mode, streaming")
            print("  - Context: 65,536 tokens")
            print("  - Max output: 65,536 tokens")
            print("  - Note: No temperature/top_p/penalty controls")
            
            print("\n" + "-" * 60)
            
            if verbose {
                print("\nError details: \(error.localizedDescription)")
            }
        }
    }
}

// Helper to repeat string
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}