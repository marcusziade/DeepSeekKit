import Foundation

/// A builder for creating function definitions with a more Swift-friendly API.
public struct FunctionBuilder {
    private var name: String
    private var description: String
    private var parameters: [String: Any] = [
        "type": "object",
        "properties": [:],
        "required": []
    ]
    
    /// Creates a new function builder.
    ///
    /// - Parameters:
    ///   - name: The name of the function.
    ///   - description: A description of what the function does.
    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
    
    /// Adds a string parameter to the function.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - description: The parameter description.
    ///   - required: Whether the parameter is required.
    /// - Returns: The builder for chaining.
    public func addStringParameter(
        _ name: String,
        description: String,
        required: Bool = false
    ) -> FunctionBuilder {
        var builder = self
        var properties = builder.parameters["properties"] as? [String: Any] ?? [:]
        properties[name] = [
            "type": "string",
            "description": description
        ]
        builder.parameters["properties"] = properties
        
        if required {
            var requiredParams = builder.parameters["required"] as? [String] ?? []
            requiredParams.append(name)
            builder.parameters["required"] = requiredParams
        }
        
        return builder
    }
    
    /// Adds a number parameter to the function.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - description: The parameter description.
    ///   - required: Whether the parameter is required.
    /// - Returns: The builder for chaining.
    public func addNumberParameter(
        _ name: String,
        description: String,
        required: Bool = false
    ) -> FunctionBuilder {
        var builder = self
        var properties = builder.parameters["properties"] as? [String: Any] ?? [:]
        properties[name] = [
            "type": "number",
            "description": description
        ]
        builder.parameters["properties"] = properties
        
        if required {
            var requiredParams = builder.parameters["required"] as? [String] ?? []
            requiredParams.append(name)
            builder.parameters["required"] = requiredParams
        }
        
        return builder
    }
    
    /// Adds a boolean parameter to the function.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - description: The parameter description.
    ///   - required: Whether the parameter is required.
    /// - Returns: The builder for chaining.
    public func addBooleanParameter(
        _ name: String,
        description: String,
        required: Bool = false
    ) -> FunctionBuilder {
        var builder = self
        var properties = builder.parameters["properties"] as? [String: Any] ?? [:]
        properties[name] = [
            "type": "boolean",
            "description": description
        ]
        builder.parameters["properties"] = properties
        
        if required {
            var requiredParams = builder.parameters["required"] as? [String] ?? []
            requiredParams.append(name)
            builder.parameters["required"] = requiredParams
        }
        
        return builder
    }
    
    /// Adds an array parameter to the function.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - description: The parameter description.
    ///   - itemType: The type of items in the array.
    ///   - required: Whether the parameter is required.
    /// - Returns: The builder for chaining.
    public func addArrayParameter(
        _ name: String,
        description: String,
        itemType: String,
        required: Bool = false
    ) -> FunctionBuilder {
        var builder = self
        var properties = builder.parameters["properties"] as? [String: Any] ?? [:]
        properties[name] = [
            "type": "array",
            "description": description,
            "items": ["type": itemType]
        ]
        builder.parameters["properties"] = properties
        
        if required {
            var requiredParams = builder.parameters["required"] as? [String] ?? []
            requiredParams.append(name)
            builder.parameters["required"] = requiredParams
        }
        
        return builder
    }
    
    /// Builds the function definition.
    ///
    /// - Returns: The function definition.
    public func build() -> FunctionDefinition {
        FunctionDefinition(
            name: name,
            description: description,
            parameters: parameters
        )
    }
    
    /// Builds a tool with this function.
    ///
    /// - Returns: A tool containing this function.
    public func buildTool() -> Tool {
        Tool(function: build())
    }
}