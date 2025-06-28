import Foundation

/// Response from a completion request.
public struct CompletionResponse: Codable, Sendable {
    /// Unique identifier for the completion.
    public let id: String
    
    /// Object type (always "text_completion").
    public let object: String
    
    /// Unix timestamp of when the completion was created.
    public let created: Int
    
    /// The model used for the completion.
    public let model: String
    
    /// Array of completion choices.
    public let choices: [CompletionChoice]
    
    /// Token usage statistics.
    public let usage: Usage
}

/// A completion choice.
public struct CompletionChoice: Codable, Sendable {
    /// The generated text.
    public let text: String
    
    /// The index of this choice.
    public let index: Int
    
    /// The reason the model stopped generating.
    public let finishReason: FinishReason?
    
    private enum CodingKeys: String, CodingKey {
        case text
        case index
        case finishReason = "finish_reason"
    }
}