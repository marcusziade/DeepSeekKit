import Foundation

/// Request configuration for creating a completion (FIM mode).
///
/// This is a beta feature that supports Fill-in-Middle for code completion.
public struct CompletionRequest: Codable, Sendable {
    /// The model ID to use (only deepseek-chat supports FIM).
    public let model: DeepSeekModel
    
    /// The prompt text.
    public let prompt: String
    
    /// Text after the completion.
    public let suffix: String?
    
    /// Maximum tokens to generate.
    public let maxTokens: Int?
    
    /// The sampling temperature (0-2).
    public let temperature: Double?
    
    /// Whether to stream the response.
    public let stream: Bool?
    
    /// Creates a new completion request.
    public init(
        model: DeepSeekModel = .chat,
        prompt: String,
        suffix: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        stream: Bool? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.suffix = suffix
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.stream = stream
    }
    
    private enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case suffix
        case maxTokens = "max_tokens"
        case temperature
        case stream
    }
}