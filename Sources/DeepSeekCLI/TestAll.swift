import ArgumentParser
import DeepSeekKit
import Foundation

struct TestAll: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test-all",
        abstract: "Test all DeepSeekKit features comprehensively"
    )
    
    @OptionGroup var common: CommonOptions
    
    @Flag(name: .shortAndLong, help: "Run quickly with minimal output")
    var quick = false
    
    mutating func run() async throws {
        let client = try common.getClient()
        
        print("🚀 Testing DeepSeekKit - All Features")
        print("====================================\n")
        
        var passedTests = 0
        var totalTests = 0
        
        // Test 1: Basic Chat
        totalTests += 1
        print("✅ 1. Basic Chat")
        print("----------------")
        do {
            let response = try await client.chat.createCompletion(
                ChatCompletionRequest(
                    model: .chat,
                    messages: [.user("Say hello in exactly 3 words")]
                )
            )
            if let content = response.choices.first?.message.content {
                print("Response: \(content)")
                passedTests += 1
            }
        } catch {
            print("❌ Failed: \(error)")
        }
        
        // Test 2: Streaming
        if !quick {
            totalTests += 1
            print("\n✅ 2. Streaming Chat")
            print("-------------------")
            do {
                var received = false
                for try await chunk in client.chat.createStreamingCompletion(
                    ChatCompletionRequest(
                        model: .chat,
                        messages: [.user("Count from 1 to 5")],
                        stream: true
                    )
                ) {
                    if let content = chunk.choices.first?.delta.content {
                        print(content, terminator: "")
                        received = true
                    }
                }
                if received {
                    passedTests += 1
                    print()
                }
            } catch {
                print("❌ Failed: \(error)")
            }
        }
        
        // Test 3: JSON Mode
        totalTests += 1
        print("\n✅ 3. JSON Mode")
        print("---------------")
        do {
            let response = try await client.chat.createCompletion(
                ChatCompletionRequest(
                    model: .chat,
                    messages: [.user("Create a simple user object with name and age in JSON")],
                    responseFormat: ResponseFormat(type: .jsonObject)
                )
            )
            if let content = response.choices.first?.message.content {
                print("JSON Response: \(content)")
                // Validate JSON
                if let data = content.data(using: .utf8),
                   let _ = try? JSONSerialization.jsonObject(with: data) {
                    print("✓ Valid JSON")
                    passedTests += 1
                }
            }
        } catch {
            print("❌ Failed: \(error)")
        }
        
        // Test 4: Reasoning Model
        if !quick {
            totalTests += 1
            print("\n✅ 4. Reasoning Model")
            print("--------------------")
            do {
                let response = try await client.chat.createCompletion(
                    ChatCompletionRequest(
                        model: .reasoner,
                        messages: [.user("What is 15% of 60?")]
                    )
                )
                if let content = response.choices.first?.message.content {
                    print("Answer: \(content)")
                    if let reasoning = response.choices.first?.message.reasoningContent {
                        print("Reasoning shown: \(reasoning.prefix(100))...")
                    }
                    passedTests += 1
                }
            } catch {
                print("❌ Failed: \(error)")
            }
        }
        
        // Test 5: Function Calling
        totalTests += 1
        print("\n✅ 5. Function Calling")
        print("---------------------")
        do {
            let weatherTool = FunctionBuilder(
                name: "get_weather",
                description: "Get weather information"
            )
            .addStringParameter("location", description: "City name", required: true)
            .buildTool()
            
            let response = try await client.chat.createCompletion(
                ChatCompletionRequest(
                    model: .chat,
                    messages: [.user("What's the weather in Paris?")],
                    tools: [weatherTool],
                    toolChoice: .auto
                )
            )
            
            if let toolCalls = response.choices.first?.message.toolCalls,
               !toolCalls.isEmpty {
                print("Function called: \(toolCalls.first!.function.name)")
                print("Arguments: \(toolCalls.first!.function.arguments)")
                passedTests += 1
            } else {
                print("⚠️  No function calls made")
            }
        } catch {
            print("❌ Failed: \(error)")
        }
        
        // Test 6: FIM Completion
        totalTests += 1
        print("\n✅ 6. Code Completion (FIM)")
        print("--------------------------")
        do {
            let response = try await client.chat.createCompletion(
                CompletionRequest(
                    model: .chat,
                    prompt: "function add(",
                    suffix: ") { return a + b; }"
                )
            )
            if let text = response.choices.first?.text {
                print("Completed: function add(\(text)) { return a + b; }")
                passedTests += 1
            }
        } catch {
            print("❌ Failed: \(error)")
        }
        
        // Test 7: List Models
        totalTests += 1
        print("\n✅ 7. List Models")
        print("----------------")
        do {
            let models = try await client.models.listModels()
            print("Found \(models.count) models:")
            for model in models {
                print("  - \(model.id)")
            }
            if !models.isEmpty {
                passedTests += 1
            }
        } catch {
            print("❌ Failed: \(error)")
        }
        
        // Test 8: Balance
        totalTests += 1
        print("\n✅ 8. Check Balance")
        print("------------------")
        do {
            let balance = try await client.balance.getBalance()
            if balance.isAvailable {
                for bal in balance.balances {
                    print("\(bal.currency): \(bal.totalBalance)")
                }
                passedTests += 1
            }
        } catch {
            print("❌ Failed: \(error)")
        }
        
        // Summary
        print("\n====================================")
        print("🎉 Test Summary")
        print("====================================")
        print("Passed: \(passedTests)/\(totalTests)")
        print("Success Rate: \(Int(Double(passedTests) / Double(totalTests) * 100))%")
        
        if passedTests == totalTests {
            print("\n✅ All tests passed!")
        } else {
            print("\n⚠️  Some tests failed. Check the output above.")
            throw ExitCode.failure
        }
    }
}