import Foundation

/// A chunk in a streaming chat completion response.
public struct ChatCompletionChunk: Codable, Sendable {
    /// Unique identifier for the completion.
    public let id: String
    
    /// Object type (always "chat.completion.chunk").
    public let object: String
    
    /// Unix timestamp of when the chunk was created.
    public let created: Int
    
    /// The model used for the completion.
    public let model: String
    
    /// System fingerprint.
    public let systemFingerprint: String?
    
    /// Array of completion choice deltas.
    public let choices: [ChunkChoice]
    
    /// Token usage statistics (only in final chunk).
    public let usage: Usage?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case model
        case systemFingerprint = "system_fingerprint"
        case choices
        case usage
    }
}

/// A choice delta in a streaming response.
public struct ChunkChoice: Codable, Sendable {
    /// The index of this choice.
    public let index: Int
    
    /// The message delta.
    public let delta: MessageDelta
    
    /// Log probability information.
    public let logprobs: LogProbs?
    
    /// The reason the model stopped generating.
    public let finishReason: FinishReason?
    
    private enum CodingKeys: String, CodingKey {
        case index
        case delta
        case logprobs
        case finishReason = "finish_reason"
    }
}

/// Delta content in a streaming message.
public struct MessageDelta: Codable, Sendable {
    /// The role of the message author (only in first chunk).
    public let role: MessageRole?
    
    /// The content delta.
    public let content: String?
    
    /// The reasoning content delta (for reasoner model).
    public let reasoningContent: String?
    
    /// Tool calls made by the assistant.
    public let toolCalls: [ToolCallDelta]?
    
    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
    }
}

/// Delta for a tool call in streaming.
public struct ToolCallDelta: Codable, Sendable {
    /// The index of the tool call.
    public let index: Int
    
    /// The ID of the tool call (only in first chunk).
    public let id: String?
    
    /// The type of tool (only in first chunk).
    public let type: String?
    
    /// The function call delta.
    public let function: FunctionCallDelta?
}

/// Delta for a function call.
public struct FunctionCallDelta: Codable, Sendable {
    /// The name of the function (only in first chunk).
    public let name: String?
    
    /// The arguments delta.
    public let arguments: String?
}