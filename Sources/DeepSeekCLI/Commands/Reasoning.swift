import ArgumentParser
import DeepSeekKit
import Foundation

struct Reasoning: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Test the reasoning model with complex problems"
    )
    
    @OptionGroup var common: CommonOptions
    
    @Argument(help: "The problem or question to solve")
    var problem: String
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int = 32768
    
    @Flag(name: .shortAndLong, help: "Stream the response")
    var stream = false
    
    @Flag(name: .long, help: "Show only the final answer (hide reasoning)")
    var hideReasoning = false
    
    @Flag(name: .long, help: "Show token usage breakdown")
    var showTokens = false
    
    mutating func run() async throws {
        let client = try common.getClient()
        
        let request = ChatCompletionRequest(
            model: .reasoner,
            messages: [.user(problem)],
            maxTokens: maxTokens,
            stream: stream
        )
        
        print("Using DeepSeek Reasoner to solve the problem...")
        print("Problem: \(problem)\n")
        print("-" * 60)
        print()
        
        do {
            if stream {
                await streamReasoning(client: client, request: request)
            } else {
                await nonStreamReasoning(client: client, request: request)
            }
        } catch {
            print("\nError: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    func streamReasoning(client: DeepSeekClient, request: ChatCompletionRequest) async {
        var finalAnswer = ""
        var reasoningContent = ""
        var usage: Usage?
        
        do {
            print("Streaming response...\n")
            
            for try await chunk in client.chat.createStreamingCompletion(request) {
                if let delta = chunk.choices.first?.delta {
                    if let content = delta.content {
                        finalAnswer += content
                        if !hideReasoning {
                            print(content, terminator: "")
                            fflush(stdout)
                        }
                    }
                    
                    if let reasoning = delta.reasoningContent {
                        reasoningContent += reasoning
                    }
                }
                
                if let chunkUsage = chunk.usage {
                    usage = chunkUsage
                }
            }
            
            if hideReasoning {
                print("Final Answer:")
                print(finalAnswer)
            }
            
            print("\n\n" + "-" * 60)
            
            if !hideReasoning && !reasoningContent.isEmpty {
                print("\nReasoning Process:")
                print(reasoningContent)
                print("\n" + "-" * 60)
            }
            
            if let usage = usage, showTokens {
                printUsage(usage)
            }
        } catch {
            print("\nStreaming error: \(error)")
        }
    }
    
    func nonStreamReasoning(client: DeepSeekClient, request: ChatCompletionRequest) async {
        do {
            let response = try await client.chat.createCompletion(request)
            
            if let message = response.choices.first?.message {
                if let content = message.content {
                    print("Final Answer:")
                    print(content)
                }
                
                if !hideReasoning, let reasoning = message.reasoningContent {
                    print("\n" + "-" * 60)
                    print("\nReasoning Process:")
                    print(reasoning)
                }
            }
            
            print("\n" + "-" * 60)
            
            if showTokens {
                printUsage(response.usage)
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    func printUsage(_ usage: Usage) {
        print("\nToken Usage:")
        print("  Prompt tokens: \(usage.promptTokens)")
        print("  Completion tokens: \(usage.completionTokens) (includes reasoning)")
        print("  Total tokens: \(usage.totalTokens)")
        
        if let cacheHit = usage.promptCacheHitTokens,
           let cacheMiss = usage.promptCacheMissTokens {
            print("  Cache performance:")
            print("    Hit: \(cacheHit) tokens")
            print("    Miss: \(cacheMiss) tokens")
            let hitRate = Double(cacheHit) / Double(cacheHit + cacheMiss) * 100
            print("    Hit rate: \(String(format: "%.1f", hitRate))%")
        }
        
        // Estimate cost (using standard hours pricing)
        let inputCost = Double(usage.promptTokens) / 1_000_000 * 0.55
        let outputCost = Double(usage.completionTokens) / 1_000_000 * 2.19
        let totalCost = inputCost + outputCost
        
        print("\nEstimated Cost (standard hours):")
        print("  Input: $\(String(format: "%.4f", inputCost))")
        print("  Output: $\(String(format: "%.4f", outputCost))")
        print("  Total: $\(String(format: "%.4f", totalCost))")
    }
}