import Foundation

/// Configuration for requesting chat completions from DeepSeek models.
///
/// `ChatCompletionRequest` encapsulates all parameters needed to generate AI responses,
/// from basic conversations to complex tool-using agents.
///
/// ## Basic Usage
/// ```swift
/// let request = ChatCompletionRequest(
///     model: .chat,
///     messages: [
///         .system("You are a helpful assistant"),
///         .user("Explain quantum computing")
///     ]
/// )
/// ```
///
/// ## Advanced Features
/// ```swift
/// let advancedRequest = ChatCompletionRequest(
///     model: .chat,
///     messages: messages,
///     temperature: 0.7,
///     maxTokens: 1000,
///     stream: true,
///     responseFormat: .json,
///     tools: [weatherTool, calculatorTool],
///     toolChoice: .auto
/// )
/// ```
///
/// ## Model-Specific Constraints
/// - The `reasoner` model doesn't support: `temperature`, `topP`, `frequencyPenalty`, `presencePenalty`
/// - Function calling is available for both models
/// - Streaming is supported by both models
///
/// - Important: Always check the model's capabilities before using advanced parameters.
public struct ChatCompletionRequest: Codable, Sendable {
    /// The AI model to use for completion. See ``DeepSeekModel`` for available options.
    public let model: DeepSeekModel
    
    /// The conversation history as an array of messages. Messages should be in chronological order.
    public let messages: [ChatMessage]
    
    /// Controls randomness in the output (0.0 to 2.0).
    /// - 0.0: Deterministic, always picks the most likely token
    /// - 1.0: Default sampling
    /// - 2.0: Maximum randomness
    /// - Note: Not supported by the reasoner model.
    public let temperature: Double?
    
    /// Nucleus sampling cutoff (0.0 to 1.0). The model considers tokens with top_p probability mass.
    /// - Note: Not supported by the reasoner model.
    public let topP: Double?
    
    /// Maximum number of tokens to generate. Defaults to model's maximum if not specified.
    public let maxTokens: Int?
    
    /// Enable streaming to receive tokens as they're generated. Useful for real-time display.
    public let stream: Bool?
    
    /// Stop sequences that will halt generation when encountered. Can be a single string or array.
    public let stop: StringOrArray?
    
    /// Penalizes tokens based on their frequency in the output (-2.0 to 2.0).
    /// Positive values decrease likelihood of repetition.
    /// - Note: Not supported by the reasoner model.
    public let frequencyPenalty: Double?
    
    /// Penalizes tokens based on whether they've appeared (-2.0 to 2.0).
    /// Positive values encourage new topics.
    /// - Note: Not supported by the reasoner model.
    public let presencePenalty: Double?
    
    /// Enforces a specific output format. Use `.json` for structured data generation.
    public let responseFormat: ResponseFormat?
    
    /// Functions/tools the model can call. Enables agent-like behavior with external capabilities.
    public let tools: [Tool]?
    
    /// Strategy for tool selection. Use `.auto` to let the model decide, or force specific tools.
    public let toolChoice: ToolChoice?
    
    /// Request log probabilities for tokens. Useful for analyzing model confidence.
    public let logprobs: Bool?
    
    /// Number of most likely tokens to return log probabilities for (0-20).
    public let topLogprobs: Int?
    
    /// Creates a new chat completion request with the specified parameters.
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

/// Available DeepSeek model identifiers.
///
/// DeepSeek provides two primary models with different capabilities:
///
/// ## Chat Model
/// The standard chat model (`deepseek-chat`) is optimized for:
/// - Fast response times
/// - General conversational AI
/// - Code generation and assistance
/// - Creative writing
/// - Question answering
///
/// ## Reasoning Model
/// The reasoning model (`deepseek-reasoner`) excels at:
/// - Complex mathematical problems
/// - Multi-step logical reasoning
/// - Scientific analysis
/// - Strategic planning
/// - Detailed explanations
///
/// ### Usage Example
/// ```swift
/// // Use the chat model for general conversations
/// let chatRequest = ChatCompletionRequest(
///     model: .chat,
///     messages: [.user("Tell me a joke")]
/// )
///
/// // Use the reasoning model for complex problems
/// let reasoningRequest = ChatCompletionRequest(
///     model: .reasoner,
///     messages: [.user("Prove that the sum of angles in a triangle is 180 degrees")]
/// )
/// ```
///
/// - Note: The reasoning model may have longer response times but provides
///   more thorough analysis with step-by-step reasoning.
public enum DeepSeekModel: String, Codable, Sendable {
    /// Standard chat model for general-purpose conversations.
    case chat = "deepseek-chat"
    
    /// Advanced reasoning model for complex problem-solving.
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