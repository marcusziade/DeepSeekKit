import Foundation

/// Protocol defining the balance service interface.
///
/// This protocol provides methods for querying user account balance
/// and usage information.
public protocol BalanceServiceProtocol: Sendable {
    /// Retrieves the user's account balance.
    ///
    /// - Returns: The user's balance information.
    /// - Throws: `DeepSeekError` if the request fails.
    func getBalance() async throws -> BalanceResponse
}