import Foundation

public extension ChatMessage {
    /// Creates a system message.
    ///
    /// - Parameter content: The content of the system message.
    /// - Returns: A new system message.
    static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }
    
    /// Creates a user message.
    ///
    /// - Parameter content: The content of the user message.
    /// - Returns: A new user message.
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }
    
    /// Creates an assistant message.
    ///
    /// - Parameters:
    ///   - content: The content of the assistant message.
    ///   - toolCalls: Optional tool calls made by the assistant.
    /// - Returns: A new assistant message.
    static func assistant(_ content: String, toolCalls: [ToolCall]? = nil) -> ChatMessage {
        ChatMessage(role: .assistant, content: content, toolCalls: toolCalls)
    }
    
    /// Creates a tool message.
    ///
    /// - Parameters:
    ///   - content: The content of the tool response.
    ///   - toolCallId: The ID of the tool call this is responding to.
    ///   - name: The name of the tool.
    /// - Returns: A new tool message.
    static func tool(content: String, toolCallId: String, name: String? = nil) -> ChatMessage {
        ChatMessage(role: .tool, content: content, name: name, toolCallId: toolCallId)
    }
}