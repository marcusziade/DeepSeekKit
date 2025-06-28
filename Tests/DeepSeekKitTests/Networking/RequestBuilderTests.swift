import XCTest
@testable import DeepSeekKit

final class RequestBuilderTests: XCTestCase {
    var requestBuilder: RequestBuilder!
    
    override func setUp() {
        super.setUp()
        requestBuilder = RequestBuilder(
            baseURL: URL(string: "https://api.deepseek.com/v1")!,
            apiKey: "test-api-key"
        )
    }
    
    func testChatCompletionRequest() throws {
        let chatRequest = ChatCompletionRequest(
            model: .chat,
            messages: [ChatMessage.user("Hello")]
        )
        
        let urlRequest = try requestBuilder.chatCompletionRequest(chatRequest)
        
        XCTAssertEqual(urlRequest.url?.absoluteString, "https://api.deepseek.com/v1/chat/completions")
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNotNil(urlRequest.httpBody)
    }
    
    func testCompletionRequest() throws {
        let completionRequest = CompletionRequest(
            prompt: "function test() {"
        )
        
        let urlRequest = try requestBuilder.completionRequest(completionRequest)
        
        XCTAssertEqual(urlRequest.url?.absoluteString, "https://api.deepseek.com/beta/completions")
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
        XCTAssertNotNil(urlRequest.httpBody)
    }
    
    func testListModelsRequest() {
        let urlRequest = requestBuilder.listModelsRequest()
        
        XCTAssertEqual(urlRequest.url?.absoluteString, "https://api.deepseek.com/v1/models")
        XCTAssertEqual(urlRequest.httpMethod, "GET")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(urlRequest.httpBody)
    }
    
    func testGetBalanceRequest() {
        let urlRequest = requestBuilder.getBalanceRequest()
        
        XCTAssertEqual(urlRequest.url?.absoluteString, "https://api.deepseek.com/user/balance")
        XCTAssertEqual(urlRequest.httpMethod, "GET")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
        XCTAssertNil(urlRequest.httpBody)
    }
    
    func testRequestBodyEncoding() throws {
        let chatRequest = ChatCompletionRequest(
            model: .chat,
            messages: [
                ChatMessage.system("You are helpful"),
                ChatMessage.user("What is 2+2?")
            ],
            temperature: 0.7,
            maxTokens: 100
        )
        
        let urlRequest = try requestBuilder.chatCompletionRequest(chatRequest)
        
        XCTAssertNotNil(urlRequest.httpBody)
        
        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(
            ChatCompletionRequest.self,
            from: urlRequest.httpBody!
        )
        
        XCTAssertEqual(decodedRequest.model, chatRequest.model)
        XCTAssertEqual(decodedRequest.messages.count, 2)
        XCTAssertEqual(decodedRequest.temperature, 0.7)
        XCTAssertEqual(decodedRequest.maxTokens, 100)
    }
}