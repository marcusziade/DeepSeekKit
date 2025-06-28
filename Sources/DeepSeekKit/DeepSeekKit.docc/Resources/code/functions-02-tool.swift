import SwiftUI
import DeepSeekKit

// Define a simple function tool
struct SimpleFunctionTool {
    
    // MARK: - Basic Tool Definition
    
    static func createCalculatorTool() -> ChatCompletionRequest.Tool {
        ChatCompletionRequest.Tool(
            type: .function,
            function: ChatCompletionRequest.Tool.Function(
                name: "calculate",
                description: "Perform basic mathematical calculations",
                parameters: [
                    "type": "object",
                    "properties": [
                        "expression": [
                            "type": "string",
                            "description": "The mathematical expression to evaluate (e.g., '2 + 2', '10 * 5')"
                        ],
                        "operation": [
                            "type": "string",
                            "enum": ["add", "subtract", "multiply", "divide"],
                            "description": "The mathematical operation to perform"
                        ],
                        "operands": [
                            "type": "array",
                            "items": ["type": "number"],
                            "description": "Array of numbers to operate on"
                        ]
                    ],
                    "required": ["expression"]
                ]
            )
        )
    }
    
    // MARK: - Multiple Tools Example
    
    static func createUtilityTools() -> [ChatCompletionRequest.Tool] {
        [
            // Time tool
            ChatCompletionRequest.Tool(
                type: .function,
                function: ChatCompletionRequest.Tool.Function(
                    name: "get_current_time",
                    description: "Get the current time in a specified timezone",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "timezone": [
                                "type": "string",
                                "description": "The timezone identifier (e.g., 'America/New_York', 'Europe/London')"
                            ]
                        ],
                        "required": []
                    ]
                )
            ),
            
            // Unit conversion tool
            ChatCompletionRequest.Tool(
                type: .function,
                function: ChatCompletionRequest.Tool.Function(
                    name: "convert_units",
                    description: "Convert between different units of measurement",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "value": [
                                "type": "number",
                                "description": "The numerical value to convert"
                            ],
                            "from_unit": [
                                "type": "string",
                                "description": "The unit to convert from"
                            ],
                            "to_unit": [
                                "type": "string",
                                "description": "The unit to convert to"
                            ]
                        ],
                        "required": ["value", "from_unit", "to_unit"]
                    ]
                )
            ),
            
            // Random number generator
            ChatCompletionRequest.Tool(
                type: .function,
                function: ChatCompletionRequest.Tool.Function(
                    name: "generate_random_number",
                    description: "Generate a random number within a specified range",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "min": [
                                "type": "integer",
                                "description": "Minimum value (inclusive)"
                            ],
                            "max": [
                                "type": "integer",
                                "description": "Maximum value (inclusive)"
                            ],
                            "decimal_places": [
                                "type": "integer",
                                "description": "Number of decimal places (0 for integer)",
                                "default": 0
                            ]
                        ],
                        "required": ["min", "max"]
                    ]
                )
            )
        ]
    }
    
    // MARK: - Complex Tool with Nested Parameters
    
    static func createDatabaseQueryTool() -> ChatCompletionRequest.Tool {
        ChatCompletionRequest.Tool(
            type: .function,
            function: ChatCompletionRequest.Tool.Function(
                name: "query_database",
                description: "Query a database with various filters and options",
                parameters: [
                    "type": "object",
                    "properties": [
                        "table": [
                            "type": "string",
                            "description": "The database table to query"
                        ],
                        "filters": [
                            "type": "object",
                            "properties": [
                                "conditions": [
                                    "type": "array",
                                    "items": [
                                        "type": "object",
                                        "properties": [
                                            "field": ["type": "string"],
                                            "operator": [
                                                "type": "string",
                                                "enum": ["=", "!=", ">", "<", ">=", "<=", "LIKE", "IN"]
                                            ],
                                            "value": ["type": "string"]
                                        ]
                                    ]
                                ],
                                "logic": [
                                    "type": "string",
                                    "enum": ["AND", "OR"],
                                    "default": "AND"
                                ]
                            ]
                        ],
                        "sort": [
                            "type": "object",
                            "properties": [
                                "field": ["type": "string"],
                                "direction": [
                                    "type": "string",
                                    "enum": ["ASC", "DESC"],
                                    "default": "ASC"
                                ]
                            ]
                        ],
                        "limit": [
                            "type": "integer",
                            "description": "Maximum number of results",
                            "default": 10
                        ]
                    ],
                    "required": ["table"]
                ]
            )
        )
    }
}

// MARK: - Tool Usage Example

struct FunctionToolDemoView: View {
    @StateObject private var client = DeepSeekClient(
        apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
    )
    @State private var selectedTool = 0
    @State private var userInput = ""
    @State private var response = ""
    @State private var isLoading = false
    
    let tools = [
        ("Calculator", SimpleFunctionTool.createCalculatorTool()),
        ("Database Query", SimpleFunctionTool.createDatabaseQueryTool())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Tool selector
            Picker("Select Tool", selection: $selectedTool) {
                ForEach(0..<tools.count, id: \.self) { index in
                    Text(tools[index].0).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Tool details
            ToolDetailsView(tool: tools[selectedTool].1)
            
            // Input
            TextField("Ask something that would use this tool...", text: $userInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Send button
            Button(action: sendRequest) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Send Request")
                }
            }
            .disabled(userInput.isEmpty || isLoading)
            
            // Response
            if !response.isEmpty {
                Text("Response:")
                    .font(.headline)
                
                Text(response)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Function Tools")
    }
    
    private func sendRequest() {
        Task {
            await performRequest()
        }
    }
    
    @MainActor
    private func performRequest() async {
        isLoading = true
        response = ""
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: [
                    Message(role: .user, content: userInput)
                ],
                tools: [tools[selectedTool].1]
            )
            
            let result = try await client.chat.completions(request)
            
            if let toolCalls = result.choices.first?.message.toolCalls {
                response = "AI wants to call: \(toolCalls.first?.function.name ?? "unknown")\n"
                response += "With arguments: \(toolCalls.first?.function.arguments ?? "{}")"
            } else {
                response = result.choices.first?.message.content ?? "No response"
            }
        } catch {
            response = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct ToolDetailsView: View {
    let tool: ChatCompletionRequest.Tool
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(tool.function.name)
                        .font(.headline)
                    
                    Text(tool.function.description ?? "No description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            
            if isExpanded {
                // Parameters display
                if let parameters = tool.function.parameters as? [String: Any] {
                    ParametersView(parameters: parameters)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ParametersView: View {
    let parameters: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parameters:")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if let properties = parameters["properties"] as? [String: Any] {
                ForEach(Array(properties.keys.sorted()), id: \.self) { key in
                    if let property = properties[key] as? [String: Any] {
                        ParameterRow(name: key, details: property)
                    }
                }
            }
            
            if let required = parameters["required"] as? [String], !required.isEmpty {
                HStack {
                    Text("Required:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(required.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct ParameterRow: View {
    let name: String
    let details: [String: Any]
    
    var body: some View {
        HStack(alignment: .top) {
            Text("• \(name):")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            
            VStack(alignment: .leading) {
                if let type = details["type"] as? String {
                    Text(type)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if let description = details["description"] as? String {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let enumValues = details["enum"] as? [String] {
                    Text("Options: \(enumValues.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
    }
}