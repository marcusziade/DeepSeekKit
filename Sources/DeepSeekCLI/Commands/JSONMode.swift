import ArgumentParser
import DeepSeekKit
import Foundation

struct JSONMode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Test JSON mode output"
    )
    
    @OptionGroup var common: CommonOptions
    
    @Argument(help: "The prompt (must mention 'json' for JSON mode to work)")
    var prompt: String
    
    @Option(name: .shortAndLong, help: "Model to use (chat or reasoner)")
    var model: String = "chat"
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int = 1000
    
    @Flag(name: .shortAndLong, help: "Pretty print the JSON output")
    var pretty = false
    
    mutating func run() async throws {
        let client = try common.getClient()
        
        let modelType: DeepSeekModel = model == "reasoner" ? .reasoner : .chat
        
        // Ensure prompt mentions JSON
        var finalPrompt = prompt
        if !prompt.lowercased().contains("json") {
            print("Warning: Prompt should mention 'json' for JSON mode to work properly")
            finalPrompt += " Please respond in JSON format."
        }
        
        let request = ChatCompletionRequest(
            model: modelType,
            messages: [.user(finalPrompt)],
            maxTokens: maxTokens,
            responseFormat: ResponseFormat(type: .jsonObject)
        )
        
        print("Testing JSON mode with \(modelType.rawValue)...")
        print("Prompt: \(finalPrompt)\n")
        
        do {
            let response = try await client.chat.createCompletion(request)
            
            if let content = response.choices.first?.message.content {
                print("Raw response:")
                print(content)
                
                // Try to parse and pretty print if requested
                if pretty, let data = content.data(using: .utf8) {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        let prettyData = try JSONSerialization.data(
                            withJSONObject: json,
                            options: [.prettyPrinted, .sortedKeys]
                        )
                        if let prettyString = String(data: prettyData, encoding: .utf8) {
                            print("\nPretty printed:")
                            print(prettyString)
                        }
                    } catch {
                        print("\nNote: Could not parse response as valid JSON")
                    }
                }
                
                // Validate JSON
                if let data = content.data(using: .utf8) {
                    do {
                        _ = try JSONSerialization.jsonObject(with: data)
                        print("\n✓ Valid JSON output")
                    } catch {
                        print("\n✗ Invalid JSON: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}