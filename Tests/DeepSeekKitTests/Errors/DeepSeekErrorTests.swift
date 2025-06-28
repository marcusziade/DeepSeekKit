import XCTest
@testable import DeepSeekKit

final class DeepSeekErrorTests: XCTestCase {
    func testErrorDescriptions() {
        XCTAssertEqual(
            DeepSeekError.invalidAPIKey.errorDescription,
            "Invalid API key provided"
        )
        
        XCTAssertEqual(
            DeepSeekError.rateLimitExceeded.errorDescription,
            "Rate limit exceeded"
        )
        
        XCTAssertEqual(
            DeepSeekError.insufficientBalance.errorDescription,
            "Insufficient account balance"
        )
        
        XCTAssertEqual(
            DeepSeekError.serviceUnavailable.errorDescription,
            "Service temporarily unavailable"
        )
        
        XCTAssertEqual(
            DeepSeekError.timeout.errorDescription,
            "Request timed out"
        )
        
        XCTAssertEqual(
            DeepSeekError.invalidRequest("Missing required field").errorDescription,
            "Invalid request: Missing required field"
        )
        
        XCTAssertEqual(
            DeepSeekError.streamingError("Connection lost").errorDescription,
            "Streaming error: Connection lost"
        )
    }
    
    func testNetworkErrorDescription() {
        let underlyingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "No internet connection"]
        )
        
        let error = DeepSeekError.networkError(underlyingError)
        XCTAssertEqual(
            error.errorDescription,
            "Network error: No internet connection"
        )
    }
    
    func testAPIErrorDescription() {
        let apiError = APIError(
            type: "invalid_request_error",
            message: "Invalid model specified",
            code: "model_not_found",
            param: "model"
        )
        
        let error = DeepSeekError.apiError(apiError)
        XCTAssertEqual(
            error.errorDescription,
            "API error: Invalid model specified"
        )
    }
    
    func testErrorResponseDecoding() throws {
        let json = """
        {
            "error": {
                "type": "invalid_request_error",
                "message": "The model 'invalid-model' does not exist",
                "code": "model_not_found",
                "param": "model"
            }
        }
        """
        
        let decoder = JSONDecoder()
        let errorResponse = try decoder.decode(ErrorResponse.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(errorResponse.error.type, "invalid_request_error")
        XCTAssertEqual(errorResponse.error.message, "The model 'invalid-model' does not exist")
        XCTAssertEqual(errorResponse.error.code, "model_not_found")
        XCTAssertEqual(errorResponse.error.param, "model")
    }
    
    func testAPIErrorWithMinimalFields() throws {
        let json = """
        {
            "error": {
                "message": "Something went wrong"
            }
        }
        """
        
        let decoder = JSONDecoder()
        let errorResponse = try decoder.decode(ErrorResponse.self, from: json.data(using: .utf8)!)
        
        XCTAssertNil(errorResponse.error.type)
        XCTAssertEqual(errorResponse.error.message, "Something went wrong")
        XCTAssertNil(errorResponse.error.code)
        XCTAssertNil(errorResponse.error.param)
    }
    
    func testEncodingDecodingErrors() {
        let encodingError = EncodingError.invalidValue(
            "test",
            EncodingError.Context(
                codingPath: [],
                debugDescription: "Invalid value"
            )
        )
        
        let deepSeekEncodingError = DeepSeekError.encodingError(encodingError)
        XCTAssertTrue(deepSeekEncodingError.errorDescription?.contains("Failed to encode request") ?? false)
        
        let decodingError = DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid JSON"
            )
        )
        
        let deepSeekDecodingError = DeepSeekError.decodingError(decodingError)
        XCTAssertTrue(deepSeekDecodingError.errorDescription?.contains("Failed to decode response") ?? false)
    }
}