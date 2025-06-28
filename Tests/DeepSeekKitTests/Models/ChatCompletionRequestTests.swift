import XCTest
@testable import DeepSeekKit

final class ChatCompletionRequestTests: XCTestCase {
    func testBasicRequestCreation() {
        let request = ChatCompletionRequest(
            model: .chat,
            messages: [
                ChatMessage.user("Hello")
            ]
        )
        
        XCTAssertEqual(request.model, .chat)
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertEqual(request.messages.first?.content, "Hello")
        XCTAssertNil(request.temperature)
        XCTAssertNil(request.maxTokens)
    }
    
    func testFullRequestCreation() {
        let request = ChatCompletionRequest(
            model: .reasoner,
            messages: [
                ChatMessage.system("You are helpful"),
                ChatMessage.user("What is 2+2?")
            ],
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 1000,
            stream: true,
            stop: .string("STOP"),
            frequencyPenalty: 0.5,
            presencePenalty: 0.3,
            responseFormat: ResponseFormat(type: .jsonObject),
            tools: [],
            toolChoice: .auto,
            logprobs: true,
            topLogprobs: 5
        )
        
        XCTAssertEqual(request.model, .reasoner)
        XCTAssertEqual(request.messages.count, 2)
        XCTAssertEqual(request.temperature, 0.7)
        XCTAssertEqual(request.topP, 0.9)
        XCTAssertEqual(request.maxTokens, 1000)
        XCTAssertEqual(request.stream, true)
        XCTAssertEqual(request.frequencyPenalty, 0.5)
        XCTAssertEqual(request.presencePenalty, 0.3)
        XCTAssertEqual(request.responseFormat?.type, .jsonObject)
        XCTAssertEqual(request.toolChoice, .auto)
        XCTAssertEqual(request.logprobs, true)
        XCTAssertEqual(request.topLogprobs, 5)
    }
    
    func testDeepSeekModelRawValues() {
        XCTAssertEqual(DeepSeekModel.chat.rawValue, "deepseek-chat")
        XCTAssertEqual(DeepSeekModel.reasoner.rawValue, "deepseek-reasoner")
    }
    
    func testStringOrArrayEncoding() throws {
        let encoder = JSONEncoder()
        
        // Test string encoding
        let stringValue = StringOrArray.string("test")
        let stringData = try encoder.encode(stringValue)
        let stringJSON = String(data: stringData, encoding: .utf8)
        XCTAssertEqual(stringJSON, "\"test\"")
        
        // Test array encoding
        let arrayValue = StringOrArray.array(["one", "two", "three"])
        let arrayData = try encoder.encode(arrayValue)
        let arrayJSON = String(data: arrayData, encoding: .utf8)
        XCTAssertEqual(arrayJSON, "[\"one\",\"two\",\"three\"]")
    }
    
    func testStringOrArrayDecoding() throws {
        let decoder = JSONDecoder()
        
        // Test string decoding
        let stringJSON = "\"single\""
        let stringValue = try decoder.decode(StringOrArray.self, from: stringJSON.data(using: .utf8)!)
        if case .string(let value) = stringValue {
            XCTAssertEqual(value, "single")
        } else {
            XCTFail("Expected string value")
        }
        
        // Test array decoding
        let arrayJSON = "[\"multiple\", \"values\"]"
        let arrayValue = try decoder.decode(StringOrArray.self, from: arrayJSON.data(using: .utf8)!)
        if case .array(let values) = arrayValue {
            XCTAssertEqual(values, ["multiple", "values"])
        } else {
            XCTFail("Expected array value")
        }
    }
    
    func testResponseFormatTypes() {
        XCTAssertEqual(ResponseFormatType.text.rawValue, "text")
        XCTAssertEqual(ResponseFormatType.jsonObject.rawValue, "json_object")
    }
    
    func testRequestEncoding() throws {
        let request = ChatCompletionRequest(
            model: .chat,
            messages: [
                ChatMessage.user("Test message")
            ],
            temperature: 0.8,
            maxTokens: 500
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"model\":\"deepseek-chat\""))
        XCTAssertTrue(json.contains("\"temperature\":0.8"))
        XCTAssertTrue(json.contains("\"max_tokens\":500"))
        XCTAssertTrue(json.contains("\"messages\""))
    }
}