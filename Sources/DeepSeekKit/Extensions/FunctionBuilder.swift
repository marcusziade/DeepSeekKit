import Foundation

/// A fluent builder for creating function definitions with a Swift-friendly API.
///
/// `FunctionBuilder` provides a convenient way to construct function definitions
/// without manually creating JSON Schema structures. It supports common parameter
/// types and handles the complexity of building valid schemas.
///
/// ## Example Usage
/// ```swift
/// let function = FunctionBuilder(
///     name: "search_products",
///     description: "Search for products in the catalog"
/// )
/// .addStringParameter("query", description: "Search query", required: true)
/// .addNumberParameter("maxPrice", description: "Maximum price filter")
/// .addStringParameter("category", description: "Product category", enum: ["electronics", "clothing", "books"])
/// .addBooleanParameter("inStock", description: "Only show in-stock items")
/// .build()
///
/// let tool = Tool(function: function)
/// ```
///
/// ## Supported Parameter Types
/// - **String**: Text parameters with optional enum constraints
/// - **Number**: Numeric parameters (integers or decimals)
/// - **Boolean**: True/false parameters
/// - **Array**: Lists of values
/// - **Object**: Nested object structures
///
/// ## Chaining
/// All parameter addition methods return `self`, allowing for fluent chaining
/// of multiple parameters in a single expression.
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