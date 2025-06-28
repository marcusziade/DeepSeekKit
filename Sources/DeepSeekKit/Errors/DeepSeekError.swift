import Foundation

/// Errors that can occur when using the DeepSeek SDK.
public enum DeepSeekError: LocalizedError, Sendable {
    /// Invalid API key provided.
    case invalidAPIKey
    
    /// Network request failed.
    case networkError(Error)
    
    /// Server returned an error response.
    case apiError(APIError)
    
    /// Failed to decode the response.
    case decodingError(Error)
    
    /// Failed to encode the request.
    case encodingError(Error)
    
    /// Invalid request configuration.
    case invalidRequest(String)
    
    /// Rate limit exceeded.
    case rateLimitExceeded
    
    /// Insufficient balance.
    case insufficientBalance
    
    /// Service temporarily unavailable.
    case serviceUnavailable
    
    /// Request timeout.
    case timeout
    
    /// Streaming error.
    case streamingError(String)
    
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