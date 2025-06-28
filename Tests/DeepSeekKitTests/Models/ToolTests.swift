import XCTest
@testable import DeepSeekKit

final class ToolTests: XCTestCase {
    func testToolCreation() {
        let function = FunctionDefinition(
            name: "get_weather",
            description: "Get weather information",
            parameters: [
                "type": "object",
                "properties": [
                    "location": [
                        "type": "string",
                        "description": "City name"
                    ]
                ],
                "required": ["location"]
            ]
        )
        
        let tool = Tool(function: function)
        
        XCTAssertEqual(tool.type, "function")
        XCTAssertEqual(tool.function.name, "get_weather")
        XCTAssertEqual(tool.function.description, "Get weather information")
        XCTAssertNotNil(tool.function.parameters["properties"])
    }
    
    func testToolChoiceEncoding() throws {
        let encoder = JSONEncoder()
        
        // Test none
        let noneData = try encoder.encode(ToolChoice.none)
        XCTAssertEqual(String(data: noneData, encoding: .utf8), "\"none\"")
        
        // Test auto
        let autoData = try encoder.encode(ToolChoice.auto)
        XCTAssertEqual(String(data: autoData, encoding: .utf8), "\"auto\"")
        
        // Test required
        let requiredData = try encoder.encode(ToolChoice.required)
        XCTAssertEqual(String(data: requiredData, encoding: .utf8), "\"required\"")
        
        // Test function
        let functionChoice = ToolChoice.function(name: "get_weather")
        let functionData = try encoder.encode(functionChoice)
        let functionJSON = String(data: functionData, encoding: .utf8)!
        XCTAssertTrue(functionJSON.contains("\"type\":\"function\""))
        XCTAssertTrue(functionJSON.contains("\"get_weather\""))
    }
    
    func testToolChoiceDecoding() throws {
        let decoder = JSONDecoder()
        
        // Test string values
        let none = try decoder.decode(ToolChoice.self, from: "\"none\"".data(using: .utf8)!)
        XCTAssertEqual(none, .none)
        
        let auto = try decoder.decode(ToolChoice.self, from: "\"auto\"".data(using: .utf8)!)
        XCTAssertEqual(auto, .auto)
        
        let required = try decoder.decode(ToolChoice.self, from: "\"required\"".data(using: .utf8)!)
        XCTAssertEqual(required, .required)
        
        // Test function object
        let functionJSON = """
        {
            "type": "function",
            "function": {
                "name": "test_function"
            }
        }
        """
        let function = try decoder.decode(ToolChoice.self, from: functionJSON.data(using: .utf8)!)
        if case .function(let name) = function {
            XCTAssertEqual(name, "test_function")
        } else {
            XCTFail("Expected function choice")
        }
    }
    
    func testFunctionDefinitionEncodingDecoding() throws {
        let originalFunction = FunctionDefinition(
            name: "calculate",
            description: "Perform calculations",
            parameters: [
                "type": "object",
                "properties": [
                    "expression": [
                        "type": "string",
                        "description": "Math expression"
                    ],
                    "precision": [
                        "type": "number",
                        "description": "Decimal precision"
                    ]
                ],
                "required": ["expression"]
            ]
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalFunction)
        let decodedFunction = try decoder.decode(FunctionDefinition.self, from: data)
        
        XCTAssertEqual(decodedFunction.name, originalFunction.name)
        XCTAssertEqual(decodedFunction.description, originalFunction.description)
        
        // Verify parameters structure
        XCTAssertNotNil(decodedFunction.parameters["type"])
        XCTAssertNotNil(decodedFunction.parameters["properties"])
        XCTAssertNotNil(decodedFunction.parameters["required"])
    }
}