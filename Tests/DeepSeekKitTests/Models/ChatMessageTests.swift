import XCTest
@testable import DeepSeekKit

final class ChatMessageTests: XCTestCase {
    func testChatMessageCreation() {
        let message = ChatMessage(
            role: .user,
            content: "Hello",
            name: "TestUser",
            toolCallId: "123",
            toolCalls: nil,
            prefix: false
        )
        
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertEqual(message.name, "TestUser")
        XCTAssertEqual(message.toolCallId, "123")
        XCTAssertNil(message.toolCalls)
        XCTAssertEqual(message.prefix, false)
    }
    
    func testConvenienceInitializers() {
        let systemMessage = ChatMessage.system("System prompt")
        XCTAssertEqual(systemMessage.role, .system)
        XCTAssertEqual(systemMessage.content, "System prompt")
        
        let userMessage = ChatMessage.user("User input")
        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(userMessage.content, "User input")
        
        let assistantMessage = ChatMessage.assistant("Assistant response")
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.content, "Assistant response")
        
        let toolMessage = ChatMessage.tool(
            content: "Tool result",
            toolCallId: "456",
            name: "weather"
        )
        XCTAssertEqual(toolMessage.role, .tool)
        XCTAssertEqual(toolMessage.content, "Tool result")
        XCTAssertEqual(toolMessage.toolCallId, "456")
        XCTAssertEqual(toolMessage.name, "weather")
    }
    
    func testMessageRoleRawValues() {
        XCTAssertEqual(MessageRole.system.rawValue, "system")
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.tool.rawValue, "tool")
    }
    
    func testToolCallCreation() {
        let functionCall = FunctionCall(name: "get_weather", arguments: "{\"location\":\"London\"}")
        let toolCall = ToolCall(id: "call_123", type: "function", function: functionCall)
        
        XCTAssertEqual(toolCall.id, "call_123")
        XCTAssertEqual(toolCall.type, "function")
        XCTAssertEqual(toolCall.function.name, "get_weather")
        XCTAssertEqual(toolCall.function.arguments, "{\"location\":\"London\"}")
    }
    
    func testChatMessageEncoding() throws {
        let message = ChatMessage(
            role: .user,
            content: "Test",
            toolCallId: "123"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)
        
        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("\"role\":\"user\""))
        XCTAssertTrue(json!.contains("\"content\":\"Test\""))
        XCTAssertTrue(json!.contains("\"tool_call_id\":\"123\""))
    }
    
    func testChatMessageDecoding() throws {
        let json = """
        {
            "role": "assistant",
            "content": "Hello there!",
            "tool_calls": [{
                "id": "call_456",
                "type": "function",
                "function": {
                    "name": "test_function",
                    "arguments": "{}"
                }
            }]
        }
        """
        
        let decoder = JSONDecoder()
        let message = try decoder.decode(ChatMessage.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hello there!")
        XCTAssertNotNil(message.toolCalls)
        XCTAssertEqual(message.toolCalls?.count, 1)
        XCTAssertEqual(message.toolCalls?.first?.id, "call_456")
        XCTAssertEqual(message.toolCalls?.first?.function.name, "test_function")
    }
}