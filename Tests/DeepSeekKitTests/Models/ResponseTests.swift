import XCTest
@testable import DeepSeekKit

final class ResponseTests: XCTestCase {
    func testChatCompletionResponseDecoding() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1234567890,
            "model": "deepseek-chat",
            "system_fingerprint": "fp_123",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Hello! How can I help you?"
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 20,
                "total_tokens": 30,
                "prompt_cache_hit_tokens": 5,
                "prompt_cache_miss_tokens": 5
            }
        }
        """
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(ChatCompletionResponse.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(response.id, "chatcmpl-123")
        XCTAssertEqual(response.object, "chat.completion")
        XCTAssertEqual(response.created, 1234567890)
        XCTAssertEqual(response.model, "deepseek-chat")
        XCTAssertEqual(response.systemFingerprint, "fp_123")
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices.first?.message.content, "Hello! How can I help you?")
        XCTAssertEqual(response.usage.promptTokens, 10)
        XCTAssertEqual(response.usage.completionTokens, 20)
        XCTAssertEqual(response.usage.totalTokens, 30)
    }
    
    func testReasonerResponseDecoding() throws {
        let json = """
        {
            "id": "chatcmpl-456",
            "object": "chat.completion",
            "created": 1234567890,
            "model": "deepseek-reasoner",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "The answer is 4",
                    "reasoning_content": "Let me calculate 2+2..."
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 15,
                "completion_tokens": 100,
                "total_tokens": 115
            }
        }
        """
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(ChatCompletionResponse.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(response.choices.first?.message.content, "The answer is 4")
        XCTAssertEqual(response.choices.first?.message.reasoningContent, "Let me calculate 2+2...")
    }
    
    func testFinishReasonValues() {
        XCTAssertEqual(FinishReason.stop.rawValue, "stop")
        XCTAssertEqual(FinishReason.length.rawValue, "length")
        XCTAssertEqual(FinishReason.toolCalls.rawValue, "tool_calls")
        XCTAssertEqual(FinishReason.contentFilter.rawValue, "content_filter")
    }
    
    func testStreamingChunkDecoding() throws {
        let json = """
        {
            "id": "chatcmpl-789",
            "object": "chat.completion.chunk",
            "created": 1234567890,
            "model": "deepseek-chat",
            "choices": [{
                "index": 0,
                "delta": {
                    "content": "Hello"
                }
            }]
        }
        """
        
        let decoder = JSONDecoder()
        let chunk = try decoder.decode(ChatCompletionChunk.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(chunk.id, "chatcmpl-789")
        XCTAssertEqual(chunk.object, "chat.completion.chunk")
        XCTAssertEqual(chunk.choices.first?.delta.content, "Hello")
        XCTAssertNil(chunk.usage)
    }
    
    func testModelsResponseDecoding() throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "deepseek-chat",
                    "object": "model",
                    "created": 1234567890,
                    "owned_by": "deepseek"
                },
                {
                    "id": "deepseek-reasoner",
                    "object": "model",
                    "created": 1234567891,
                    "owned_by": "deepseek"
                }
            ]
        }
        """
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(ModelsResponse.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(response.object, "list")
        XCTAssertEqual(response.data.count, 2)
        XCTAssertEqual(response.data[0].id, "deepseek-chat")
        XCTAssertEqual(response.data[1].id, "deepseek-reasoner")
    }
    
    func testBalanceResponseDecoding() throws {
        let json = """
        {
            "is_available": true,
            "balance_infos": [
                {
                    "currency": "USD",
                    "total_balance": "100.00",
                    "granted_balance": "50.00",
                    "topped_up_balance": "50.00"
                },
                {
                    "currency": "CNY",
                    "total_balance": "700.00",
                    "granted_balance": "350.00",
                    "topped_up_balance": "350.00"
                }
            ]
        }
        """
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(BalanceResponse.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(response.balances.count, 2)
        XCTAssertEqual(response.balances[0].currency, "USD")
        XCTAssertEqual(response.balances[0].totalBalance, "100.00")
        XCTAssertEqual(response.balances[1].currency, "CNY")
    }
    
    func testCompletionResponseDecoding() throws {
        let json = """
        {
            "id": "cmpl-123",
            "object": "text_completion",
            "created": 1234567890,
            "model": "deepseek-chat",
            "choices": [{
                "text": "function example() {",
                "index": 0,
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 20,
                "completion_tokens": 10,
                "total_tokens": 30
            }
        }
        """
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(CompletionResponse.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(response.id, "cmpl-123")
        XCTAssertEqual(response.object, "text_completion")
        XCTAssertEqual(response.choices.first?.text, "function example() {")
    }
}