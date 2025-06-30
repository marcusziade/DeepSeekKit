import Foundation

/// Represents a tool or function that the AI model can invoke during conversations.
///
/// Tools enable AI models to perform actions beyond text generation, such as:
/// - Retrieving real-time data (weather, stock prices)
/// - Performing calculations
/// - Interacting with external systems
/// - Executing custom business logic
///
/// ## Example
/// ```swift
/// let weatherTool = Tool(
///     function: FunctionDefinition(
///         name: "get_weather",
///         description: "Get current weather for a location",
///         parameters: [
///             "type": "object",
///             "properties": [
///                 "location": [
///                     "type": "string",
///                     "description": "City and state, e.g. San Francisco, CA"
///                 ]
///             ],
///             "required": ["location"]
///         ]
///     )
/// )
/// ```
public struct Tool: Codable, Sendable {
    /// The type of tool. Currently only "function" is supported.
    public let type: String
    
    /// The function definition containing name, description, and parameters.
    public let function: FunctionDefinition
    
    /// Creates a new tool with the specified function definition.
    /// - Parameter function: The function definition for this tool.
    public init(function: FunctionDefinition) {
        self.type = "function"
        self.function = function
    }
}

/// Defines a function that can be called by the AI model.
///
/// Function definitions follow the JSON Schema specification for parameters,
/// allowing you to specify complex parameter structures with validation rules.
///
/// ## Parameter Schema
/// The `parameters` dictionary should follow JSON Schema format:
/// - `type`: The parameter type ("object", "array", "string", etc.)
/// - `properties`: Object properties (for object types)
/// - `required`: Array of required property names
/// - `description`: Human-readable descriptions
///
/// ## Best Practices
/// - Use clear, descriptive function names
/// - Provide detailed descriptions to help the model understand when to use the function
/// - Define all parameters clearly with appropriate types and constraints
/// - Mark required parameters explicitly
public struct FunctionDefinition: Codable, Sendable {
    /// The name of the function. Should be a valid identifier (letters, numbers, underscores).
    public let name: String
    
    /// A clear description of what the function does. This helps the model decide when to use it.
    public let description: String
    
    /// The parameters schema in JSON Schema format. Defines the structure and validation rules for function parameters.
    public let parameters: [String: Any]
    
    /// Creates a new function definition.
    /// - Parameters:
    ///   - name: The function name (e.g., "get_weather", "search_database")
    ///   - description: A clear description of the function's purpose
    ///   - parameters: JSON Schema defining the function's parameters
    public init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Decode parameters as a dynamic JSON structure
        if let parametersJSON = try? container.decode(JSONValue.self, forKey: .parameters) {
            parameters = parametersJSON.toDictionary() ?? [:]
        } else {
            parameters = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        
        // Encode parameters using JSONValue
        let jsonValue = JSONValue.fromDictionary(parameters)
        try container.encode(jsonValue, forKey: .parameters)
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case parameters
    }
}

/// A type that can represent any JSON value for dynamic encoding/decoding
enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let double = try? container.decode(Double.self) {
            self = .number(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> JSONValue {
        var result: [String: JSONValue] = [:]
        for (key, value) in dict {
            result[key] = fromAny(value)
        }
        return .object(result)
    }
    
    static func fromAny(_ value: Any) -> JSONValue {
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if number.isBool {
                return .bool(number.boolValue)
            } else {
                return .number(number.doubleValue)
            }
        case let bool as Bool:
            return .bool(bool)
        case let dict as [String: Any]:
            return fromDictionary(dict)
        case let array as [Any]:
            return .array(array.map { fromAny($0) })
        case is NSNull:
            return .null
        default:
            return .string(String(describing: value))
        }
    }
    
    func toDictionary() -> [String: Any]? {
        guard case .object(let dict) = self else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = value.toAny()
        }
        return result
    }
    
    func toAny() -> Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let dict):
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = value.toAny()
            }
            return result
        case .array(let array):
            return array.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
}

// Extension to check if NSNumber is a Bool
extension NSNumber {
    var isBool: Bool {
        #if os(Linux)
        // On Linux, check the objCType
        let boolID = String(cString: self.objCType)
        return boolID == "c" || boolID == "B"
        #else
        return CFBooleanGetTypeID() == CFGetTypeID(self)
        #endif
    }
}

/// Controls how the model selects tools.
public enum ToolChoice: Codable, Sendable, Equatable {
    case none
    case auto
    case required
    case function(name: String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            switch string {
            case "none":
                self = .none
            case "auto":
                self = .auto
            case "required":
                self = .required
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown tool choice: \(string)")
            }
        } else {
            let object = try container.decode(ToolChoiceObject.self)
            self = .function(name: object.function.name)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .function(let name):
            try container.encode(ToolChoiceObject(type: "function", function: .init(name: name)))
        }
    }
    
    private struct ToolChoiceObject: Codable {
        let type: String
        let function: FunctionChoice
        
        struct FunctionChoice: Codable {
            let name: String
        }
    }
}