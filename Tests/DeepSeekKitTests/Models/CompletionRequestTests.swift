import XCTest
@testable import DeepSeekKit

final class CompletionRequestTests: XCTestCase {
    func testBasicCompletionRequest() {
        let request = CompletionRequest(
            prompt: "function hello() {"
        )
        
        XCTAssertEqual(request.model, .chat)
        XCTAssertEqual(request.prompt, "function hello() {")
        XCTAssertNil(request.suffix)
        XCTAssertNil(request.maxTokens)
        XCTAssertNil(request.temperature)
        XCTAssertNil(request.stream)
    }
    
    func testFullCompletionRequest() {
        let request = CompletionRequest(
            model: .chat,
            prompt: "function calculate(",
            suffix: ") { return result; }",
            maxTokens: 100,
            temperature: 0.5,
            stream: true
        )
        
        XCTAssertEqual(request.model, .chat)
        XCTAssertEqual(request.prompt, "function calculate(")
        XCTAssertEqual(request.suffix, ") { return result; }")
        XCTAssertEqual(request.maxTokens, 100)
        XCTAssertEqual(request.temperature, 0.5)
        XCTAssertEqual(request.stream, true)
    }
    
    func testCompletionRequestEncoding() throws {
        let request = CompletionRequest(
            prompt: "test prompt",
            suffix: "test suffix",
            maxTokens: 50
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"model\":\"deepseek-chat\""))
        XCTAssertTrue(json.contains("\"prompt\":\"test prompt\""))
        XCTAssertTrue(json.contains("\"suffix\":\"test suffix\""))
        XCTAssertTrue(json.contains("\"max_tokens\":50"))
    }
    
    func testCompletionRequestDecoding() throws {
        let json = """
        {
            "model": "deepseek-chat",
            "prompt": "Complete this code",
            "suffix": "end of function",
            "max_tokens": 256,
            "temperature": 0.8,
            "stream": false
        }
        """
        
        let decoder = JSONDecoder()
        let request = try decoder.decode(CompletionRequest.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(request.model, .chat)
        XCTAssertEqual(request.prompt, "Complete this code")
        XCTAssertEqual(request.suffix, "end of function")
        XCTAssertEqual(request.maxTokens, 256)
        XCTAssertEqual(request.temperature, 0.8)
        XCTAssertEqual(request.stream, false)
    }
}