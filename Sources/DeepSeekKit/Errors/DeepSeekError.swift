import Foundation

/// Comprehensive error types for DeepSeek API interactions.
///
/// `DeepSeekError` provides detailed error information to help diagnose and handle
/// various failure scenarios when interacting with the DeepSeek API.
///
/// ## Error Categories
///
/// ### Authentication Errors
/// - `invalidAPIKey`: The provided API key is invalid or missing
///
/// ### Network Errors
/// - `networkError`: Low-level network failures (no connection, DNS issues)
/// - `timeout`: Request exceeded the timeout threshold
/// - `httpError`: HTTP-level errors with status codes
///
/// ### API Errors
/// - `apiError`: Server returned an error response with details
/// - `rateLimitExceeded`: Too many requests in a time window
/// - `insufficientBalance`: Account balance too low for request
/// - `serviceUnavailable`: DeepSeek service is temporarily down
///
/// ### Data Errors
/// - `decodingError`: Failed to parse server response
/// - `encodingError`: Failed to encode request data
/// - `invalidRequest`: Request validation failed
///
/// ### Streaming Errors
/// - `streamingError`: Issues during server-sent event streaming
///
/// ## Error Handling Example
/// ```swift
/// do {
///     let response = try await client.chat.createCompletion(request)
/// } catch DeepSeekError.rateLimitExceeded {
///     // Wait and retry
///     await Task.sleep(nanoseconds: 60_000_000_000)
/// } catch DeepSeekError.apiError(let apiError) {
///     print("API Error: \(apiError.message)")
/// } catch DeepSeekError.networkError(let error) {
///     print("Network failed: \(error)")
/// }
/// ```
public enum DeepSeekError: LocalizedError, Sendable {
    /// Invalid or missing API key. Ensure you've provided a valid API key from your DeepSeek account.
    case invalidAPIKey
    
    /// Low-level network error occurred. Check internet connection and network settings.
    case networkError(Error)
    
    /// DeepSeek API returned an error response. Contains detailed error information from the server.
    case apiError(APIError)
    
    /// Failed to decode the server response. May indicate API changes or data corruption.
    case decodingError(Error)
    
    /// Failed to encode the request data. Check that all parameters are valid.
    case encodingError(Error)
    
    /// Request validation failed. The message contains details about what's invalid.
    case invalidRequest(String)
    
    /// Rate limit exceeded. Wait before making more requests.
    case rateLimitExceeded
    
    /// Account balance insufficient for this request. Top up your DeepSeek account.
    case insufficientBalance
    
    /// DeepSeek service is temporarily unavailable. Try again later.
    case serviceUnavailable
    
    /// Request timed out. Consider using streaming for long responses.
    case timeout
    
    /// Error occurred during streaming response. Message contains specific details.
    case streamingError(String)
    
    /// HTTP error with specific status code. Check status code for more details.
    case httpError(statusCode: Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let error):
            return "API error: \(error.message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .insufficientBalance:
            return "Insufficient account balance"
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        case .timeout:
            return "Request timed out"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}

/// API error response from the server.
public struct APIError: Codable, Sendable {
    /// Error type.
    public let type: String?
    
    /// Error message.
    public let message: String
    
    /// Error code.
    public let code: String?
    
    /// Additional error details.
    public let param: String?
}

/// Error response wrapper.
public struct ErrorResponse: Codable, Sendable {
    /// The error details.
    public let error: APIError
}