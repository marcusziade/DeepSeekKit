import ArgumentParser
import DeepSeekKit
import Foundation

@main
struct DeepSeekCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deepseek-cli",
        abstract: "DeepSeek API CLI - Test and interact with all DeepSeek API features",
        version: "1.0.0",
        subcommands: [
            Chat.self,
            Stream.self,
            Complete.self,
            Models.self,
            Balance.self,
            FunctionCall.self,
            JSONMode.self,
            Reasoning.self,
            TestAll.self
        ]
    )
    
    @Option(name: .shortAndLong, help: "API key (defaults to DEEPSEEK_API_KEY env var)")
    var apiKey: String?
    
    mutating func run() async throws {
        print("DeepSeek CLI - Use --help to see available commands")
    }
}

// MARK: - Common Options

struct CommonOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "API key (defaults to DEEPSEEK_API_KEY env var)")
    var apiKey: String?
    
    func getClient() throws -> DeepSeekClient {
        let key = apiKey ?? ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]
        guard let key = key, !key.isEmpty else {
            throw ValidationError("API key required. Set DEEPSEEK_API_KEY or use --api-key")
        }
        return DeepSeekClient(apiKey: key)
    }
}