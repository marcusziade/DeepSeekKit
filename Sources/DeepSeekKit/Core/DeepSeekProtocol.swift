import Foundation

/// The main protocol defining the DeepSeek API client interface.
///
/// This protocol provides access to all DeepSeek API functionality including
/// chat completions, model information, and account balance queries.
public protocol DeepSeekProtocol: Sendable {
    /// The API key used for authentication.
    var apiKey: String { get }
    
    /// The base URL for API requests.
    var baseURL: URL { get }
    
    /// Service for chat completion operations.
    var chat: ChatServiceProtocol { get }
    
    /// Service for model-related operations.
    var models: ModelServiceProtocol { get }
    
    /// Service for user balance queries.
    var balance: BalanceServiceProtocol { get }
}