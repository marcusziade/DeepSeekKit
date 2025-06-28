import ArgumentParser
import DeepSeekKit
import Foundation

struct Balance: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check account balance"
    )
    
    @OptionGroup var common: CommonOptions
    
    @Flag(name: .shortAndLong, help: "Show detailed breakdown")
    var detailed = false
    
    mutating func run() async throws {
        let client = try common.getClient()
        
        print("Fetching account balance...\n")
        
        do {
            let balanceResponse = try await client.balance.getBalance()
            
            if balanceResponse.balances.isEmpty {
                print("No balance information available")
                return
            }
            
            print("Account Balance:")
            print("-" * 40)
            
            for balance in balanceResponse.balances {
                print("\n\(balance.currency):")
                print("  Total: \(balance.totalBalance)")
                
                if detailed {
                    print("  Granted: \(balance.grantedBalance)")
                    print("  Topped up: \(balance.toppedUpBalance)")
                }
            }
            
            print("\n" + "-" * 40)
            
            // Show pricing information
            if detailed {
                print("\nCurrent Pricing (per 1M tokens):")
                print("\nDeepSeek Chat:")
                print("  Standard hours (00:30-16:30 UTC):")
                print("    Input: $0.27 (cache miss), $0.07 (cache hit)")
                print("    Output: $1.10")
                print("  Discounted hours (16:30-00:30 UTC):")
                print("    Input: $0.135 (cache miss), $0.035 (cache hit)")
                print("    Output: $0.55")
                
                print("\nDeepSeek Reasoner:")
                print("  Standard hours (00:30-16:30 UTC):")
                print("    Input: $0.55 (cache miss), $0.14 (cache hit)")
                print("    Output: $2.19 (includes reasoning tokens)")
                print("  Discounted hours (16:30-00:30 UTC):")
                print("    Input: $0.275 (cache miss), $0.07 (cache hit)")
                print("    Output: $1.095")
            }
        } catch {
            print("Note: The balance endpoint may not be available yet.")
            print("Visit https://platform.deepseek.com to check your balance.\n")
            
            // Always show pricing information when balance fails
            print("Current Pricing (per 1M tokens):")
            print("-" * 40)
            print("\nDeepSeek Chat:")
            print("  Standard hours (00:30-16:30 UTC):")
            print("    Input: $0.27 (cache miss), $0.07 (cache hit)")
            print("    Output: $1.10")
            print("  Discounted hours (16:30-00:30 UTC):")
            print("    Input: $0.135 (cache miss), $0.035 (cache hit)")
            print("    Output: $0.55")
            
            print("\nDeepSeek Reasoner:")
            print("  Standard hours (00:30-16:30 UTC):")
            print("    Input: $0.55 (cache miss), $0.14 (cache hit)")
            print("    Output: $2.19 (includes reasoning tokens)")
            print("  Discounted hours (16:30-00:30 UTC):")
            print("    Input: $0.275 (cache miss), $0.07 (cache hit)")
            print("    Output: $1.095")
            
            if detailed {
                print("\nError details: \(error.localizedDescription)")
            }
        }
    }
}