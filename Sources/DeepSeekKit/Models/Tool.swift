import Foundation

/// Represents a tool/function that the model can use.
public struct Tool: Codable, Sendable {
    /// The type of tool (currently only "function").
    public let type: String
    
    /// The function definition.
    public let function: FunctionDefinition
    
    /// Creates a new tool.
    public init(function: FunctionDefinition) {
        self.type = "function"
        self.function = function
    }
}

/// Defines a function that can be called by the model.
public struct FunctionDefinition: Codable, Sendable {
    /// The name of the function.
    public let name: String
    
    /// A description of what the function does.
    public let description: String
    
    /// The parameters the function accepts (JSON Schema).
    public let parameters: [String: Any]
    
    /// Creates a new function definition.
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
        return CFBooleanGetTypeID() == CFGetTypeID(self)
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