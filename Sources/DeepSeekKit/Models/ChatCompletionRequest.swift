import Foundation

/// Request configuration for creating a chat completion.
public struct ChatCompletionRequest: Codable, Sendable {
    /// The model ID to use.
    public let model: DeepSeekModel
    
    /// The messages in the conversation.
    public let messages: [ChatMessage]
    
    /// The sampling temperature (0-2). Not supported for reasoner model.
    public let temperature: Double?
    
    /// Nucleus sampling probability (0-1). Not supported for reasoner model.
    public let topP: Double?
    
    /// Maximum tokens to generate.
    public let maxTokens: Int?
    
    /// Whether to stream the response.
    public let stream: Bool?
    
    /// Sequences that will stop generation.
    public let stop: StringOrArray?
    
    /// Frequency penalty (-2 to 2). Not supported for reasoner model.
    public let frequencyPenalty: Double?
    
    /// Presence penalty (-2 to 2). Not supported for reasoner model.
    public let presencePenalty: Double?
    
    /// Response format configuration.
    public let responseFormat: ResponseFormat?
    
    /// Available tools/functions.
    public let tools: [Tool]?
    
    /// Tool selection strategy.
    public let toolChoice: ToolChoice?
    
    /// Whether to return log probabilities.
    public let logprobs: Bool?
    
    /// Number of top log probabilities to return (0-20).
    public let topLogprobs: Int?
    
    /// Creates a new chat completion request.
    public init(
        model: DeepSeekModel,
        messages: [ChatMessage],
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        stream: Bool? = nil,
        stop: StringOrArray? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        responseFormat: ResponseFormat? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        logprobs: Bool? = nil,
        topLogprobs: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stream = stream
        self.stop = stop
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.responseFormat = responseFormat
        self.tools = tools
        self.toolChoice = toolChoice
        self.logprobs = logprobs
        self.topLogprobs = topLogprobs
    }
    
    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stream
        case stop
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case responseFormat = "response_format"
        case tools
        case toolChoice = "tool_choice"
        case logprobs
        case topLogprobs = "top_logprobs"
    }
}

/// DeepSeek model identifiers.
public enum DeepSeekModel: String, Codable, Sendable {
    case chat = "deepseek-chat"
    case reasoner = "deepseek-reasoner"
}

/// Represents either a string or an array of strings.
public enum StringOrArray: Codable, Sendable, Equatable {
    case string(String)
    case array([String])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            let array = try container.decode([String].self)
            self = .array(array)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        }
    }
}

/// Response format configuration.
public struct ResponseFormat: Codable, Sendable, Equatable {
    /// The response format type.
    public let type: ResponseFormatType
    
    /// Creates a new response format.
    public init(type: ResponseFormatType) {
        self.type = type
    }
}

/// Response format types.
public enum ResponseFormatType: String, Codable, Sendable {
    case text = "text"
    case jsonObject = "json_object"
}