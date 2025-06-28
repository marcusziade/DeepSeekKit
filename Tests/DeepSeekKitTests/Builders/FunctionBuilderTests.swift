import XCTest
@testable import DeepSeekKit

final class FunctionBuilderTests: XCTestCase {
    func testBasicFunctionBuilder() {
        let function = FunctionBuilder(name: "test_function", description: "A test function")
            .build()
        
        XCTAssertEqual(function.name, "test_function")
        XCTAssertEqual(function.description, "A test function")
        XCTAssertNotNil(function.parameters["type"])
        XCTAssertEqual(function.parameters["type"] as? String, "object")
    }
    
    func testAddStringParameter() {
        let function = FunctionBuilder(name: "greet", description: "Greet someone")
            .addStringParameter("name", description: "Person's name", required: true)
            .addStringParameter("title", description: "Optional title", required: false)
            .build()
        
        let properties = function.parameters["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        
        let nameParam = properties?["name"] as? [String: String]
        XCTAssertEqual(nameParam?["type"], "string")
        XCTAssertEqual(nameParam?["description"], "Person's name")
        
        let titleParam = properties?["title"] as? [String: String]
        XCTAssertEqual(titleParam?["type"], "string")
        XCTAssertEqual(titleParam?["description"], "Optional title")
        
        let required = function.parameters["required"] as? [String]
        XCTAssertEqual(required, ["name"])
    }
    
    func testAddNumberParameter() {
        let function = FunctionBuilder(name: "calculate", description: "Calculate something")
            .addNumberParameter("value", description: "Input value", required: true)
            .addNumberParameter("precision", description: "Decimal precision", required: false)
            .build()
        
        let properties = function.parameters["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        
        let valueParam = properties?["value"] as? [String: String]
        XCTAssertEqual(valueParam?["type"], "number")
        XCTAssertEqual(valueParam?["description"], "Input value")
        
        let required = function.parameters["required"] as? [String]
        XCTAssertEqual(required, ["value"])
    }
    
    func testAddBooleanParameter() {
        let function = FunctionBuilder(name: "configure", description: "Configure settings")
            .addBooleanParameter("enabled", description: "Enable feature", required: true)
            .addBooleanParameter("verbose", description: "Verbose output", required: false)
            .build()
        
        let properties = function.parameters["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        
        let enabledParam = properties?["enabled"] as? [String: String]
        XCTAssertEqual(enabledParam?["type"], "boolean")
        XCTAssertEqual(enabledParam?["description"], "Enable feature")
        
        let required = function.parameters["required"] as? [String]
        XCTAssertEqual(required, ["enabled"])
    }
    
    func testAddArrayParameter() {
        let function = FunctionBuilder(name: "process", description: "Process items")
            .addArrayParameter("items", description: "Items to process", itemType: "string", required: true)
            .addArrayParameter("tags", description: "Optional tags", itemType: "string", required: false)
            .build()
        
        let properties = function.parameters["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        
        let itemsParam = properties?["items"] as? [String: Any]
        XCTAssertEqual(itemsParam?["type"] as? String, "array")
        XCTAssertEqual(itemsParam?["description"] as? String, "Items to process")
        
        let itemsType = itemsParam?["items"] as? [String: String]
        XCTAssertEqual(itemsType?["type"], "string")
        
        let required = function.parameters["required"] as? [String]
        XCTAssertEqual(required, ["items"])
    }
    
    func testComplexFunctionBuilder() {
        let function = FunctionBuilder(name: "search", description: "Search for items")
            .addStringParameter("query", description: "Search query", required: true)
            .addNumberParameter("limit", description: "Max results", required: false)
            .addBooleanParameter("includeMetadata", description: "Include metadata", required: false)
            .addArrayParameter("filters", description: "Search filters", itemType: "string", required: false)
            .build()
        
        let properties = function.parameters["properties"] as? [String: Any]
        XCTAssertEqual(properties?.count, 4)
        
        let required = function.parameters["required"] as? [String]
        XCTAssertEqual(required?.count, 1)
        XCTAssertEqual(required?.first, "query")
    }
    
    func testBuildTool() {
        let tool = FunctionBuilder(name: "get_time", description: "Get current time")
            .addStringParameter("timezone", description: "Timezone", required: false)
            .buildTool()
        
        XCTAssertEqual(tool.type, "function")
        XCTAssertEqual(tool.function.name, "get_time")
        XCTAssertEqual(tool.function.description, "Get current time")
        
        let properties = tool.function.parameters["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["timezone"])
    }
}