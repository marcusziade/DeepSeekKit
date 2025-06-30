import Foundation

/// A message in a chat conversation between users, assistants, systems, or tools.
///
/// `ChatMessage` represents a single message in a conversation thread. Messages can
/// come from different roles and may include tool interactions for function calling.
///
/// ## Message Roles
/// - **System**: Sets the assistant's behavior and context
/// - **User**: Input from the human user
/// - **Assistant**: Responses from the AI model
/// - **Tool**: Results from function/tool execution
///
/// ## Basic Usage
/// ```swift
/// // User message
/// let userMsg = ChatMessage(role: .user, content: "What's the weather?")
///
/// // System message
/// let systemMsg = ChatMessage(
///     role: .system,
///     content: "You are a helpful weather assistant."
/// )
///
/// // Assistant message with tool calls
/// let assistantMsg = ChatMessage(
///     role: .assistant,
///     content: "I'll check the weather for you.",
///     toolCalls: [
///         ToolCall(
///             id: "call_123",
///             type: "function",
///             function: FunctionCall(name: "get_weather", arguments: "{\"location\":\"NYC\"}")
///         )
///     ]
/// )
/// ```
///
/// ## Convenience Initializers
/// Use the extension methods for cleaner message creation:
/// ```swift
/// let messages: [ChatMessage] = [
///     .system("You are a helpful assistant"),
///     .user("Hello!"),
///     .assistant("Hi! How can I help you today?")
/// ]
/// ```
public struct ChatMessage: Codable, Sendable, Equatable {
    /// The role of the message author.
    public let role: MessageRole
    
    /// The content of the message.
    public let content: String
    
    /// The name of the author (for tool messages).
    public let name: String?
    
    /// The ID of the tool call this message is responding to.
    public let toolCallId: String?
    
    /// Tool calls made by the assistant.
    public let toolCalls: [ToolCall]?
    
    /// Whether this message is a prefix for chat prefix completion (beta).
    public let prefix: Bool?
    
    /// Creates a new chat message.
    ///
    /// - Parameters:
    ///   - role: The role of the message author.
    ///   - content: The content of the message.
    ///   - name: The name of the author (for tool messages).
    ///   - toolCallId: The ID of the tool call this message is responding to.
    ///   - toolCalls: Tool calls made by the assistant.
    ///   - prefix: Whether this is a prefix message for completion.
    public init(
        role: MessageRole,
        content: String,
        name: String? = nil,
        toolCallId: String? = nil,
        toolCalls: [ToolCall]? = nil,
        prefix: Bool? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
        self.prefix = prefix
    }
    
    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
        case prefix
    }
}

/// The role of a message author.
public enum MessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

/// Represents a tool call made by the assistant.
public struct ToolCall: Codable, Sendable, Equatable {
    /// The ID of the tool call.
    public let id: String
    
    /// The type of tool (always "function" currently).
    public let type: String
    
    /// The function call details.
    public let function: FunctionCall
    
    /// Creates a new tool call.
    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Represents a function call.
public struct FunctionCall: Codable, Sendable, Equatable {
    /// The name of the function to call.
    public let name: String
    
    /// The arguments to the function as a JSON string.
    public let arguments: String
    
    /// Creates a new function call.
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}