import SwiftUI
import DeepSeekKit

// FunctionBuilder for easier tool creation
class FunctionBuilder {
    private var name: String = ""
    private var description: String = ""
    private var parameters: [String: Any] = ["type": "object", "properties": [:], "required": []]
    
    init() {}
    
    // Fluent API methods
    func withName(_ name: String) -> FunctionBuilder {
        self.name = name
        return self
    }
    
    func withDescription(_ description: String) -> FunctionBuilder {
        self.description = description
        return self
    }
    
    func addParameter(
        _ name: String,
        type: ParameterType,
        description: String? = nil,
        required: Bool = false,
        enumValues: [String]? = nil,
        defaultValue: Any? = nil
    ) -> FunctionBuilder {
        var properties = parameters["properties"] as? [String: Any] ?? [:]
        var paramDef: [String: Any] = ["type": type.rawValue]
        
        if let description = description {
            paramDef["description"] = description
        }
        
        if let enumValues = enumValues {
            paramDef["enum"] = enumValues
        }
        
        if let defaultValue = defaultValue {
            paramDef["default"] = defaultValue
        }
        
        properties[name] = paramDef
        parameters["properties"] = properties
        
        if required {
            var requiredParams = parameters["required"] as? [String] ?? []
            requiredParams.append(name)
            parameters["required"] = requiredParams
        }
        
        return self
    }
    
    func addObjectParameter(
        _ name: String,
        description: String? = nil,
        required: Bool = false,
        builder: (FunctionBuilder) -> Void
    ) -> FunctionBuilder {
        let nestedBuilder = FunctionBuilder()
        builder(nestedBuilder)
        
        var properties = parameters["properties"] as? [String: Any] ?? [:]
        var paramDef: [String: Any] = [
            "type": "object",
            "properties": nestedBuilder.parameters["properties"] ?? [:]
        ]
        
        if let description = description {
            paramDef["description"] = description
        }
        
        properties[name] = paramDef
        parameters["properties"] = properties
        
        if required {
            var requiredParams = parameters["required"] as? [String] ?? []
            requiredParams.append(name)
            parameters["required"] = requiredParams
        }
        
        return self
    }
    
    func addArrayParameter(
        _ name: String,
        itemType: ParameterType,
        description: String? = nil,
        required: Bool = false
    ) -> FunctionBuilder {
        var properties = parameters["properties"] as? [String: Any] ?? [:]
        var paramDef: [String: Any] = [
            "type": "array",
            "items": ["type": itemType.rawValue]
        ]
        
        if let description = description {
            paramDef["description"] = description
        }
        
        properties[name] = paramDef
        parameters["properties"] = properties
        
        if required {
            var requiredParams = parameters["required"] as? [String] ?? []
            requiredParams.append(name)
            parameters["required"] = requiredParams
        }
        
        return self
    }
    
    func build() -> ChatCompletionRequest.Tool {
        ChatCompletionRequest.Tool(
            type: .function,
            function: ChatCompletionRequest.Tool.Function(
                name: name,
                description: description,
                parameters: parameters
            )
        )
    }
    
    enum ParameterType: String {
        case string = "string"
        case number = "number"
        case integer = "integer"
        case boolean = "boolean"
        case object = "object"
        case array = "array"
    }
}

// MARK: - Usage Examples

struct FunctionBuilderExamples {
    
    // Simple function
    static func createSimpleSearchTool() -> ChatCompletionRequest.Tool {
        FunctionBuilder()
            .withName("search_web")
            .withDescription("Search the web for information")
            .addParameter(
                "query",
                type: .string,
                description: "The search query",
                required: true
            )
            .addParameter(
                "max_results",
                type: .integer,
                description: "Maximum number of results to return",
                required: false,
                defaultValue: 10
            )
            .build()
    }
    
    // Complex function with nested parameters
    static func createEmailTool() -> ChatCompletionRequest.Tool {
        FunctionBuilder()
            .withName("send_email")
            .withDescription("Send an email message")
            .addParameter(
                "to",
                type: .string,
                description: "Recipient email address",
                required: true
            )
            .addParameter(
                "subject",
                type: .string,
                description: "Email subject line",
                required: true
            )
            .addParameter(
                "body",
                type: .string,
                description: "Email body content",
                required: true
            )
            .addParameter(
                "priority",
                type: .string,
                description: "Email priority level",
                required: false,
                enumValues: ["low", "normal", "high"],
                defaultValue: "normal"
            )
            .addArrayParameter(
                "attachments",
                itemType: .string,
                description: "List of attachment file paths",
                required: false
            )
            .addObjectParameter(
                "options",
                description: "Additional email options",
                required: false
            ) { builder in
                builder
                    .addParameter(
                        "send_later",
                        type: .boolean,
                        description: "Schedule email for later",
                        defaultValue: false
                    )
                    .addParameter(
                        "send_at",
                        type: .string,
                        description: "ISO 8601 timestamp for scheduled send"
                    )
                    .addParameter(
                        "track_opens",
                        type: .boolean,
                        description: "Track when email is opened",
                        defaultValue: false
                    )
            }
            .build()
    }
    
    // Data processing function
    static func createDataAnalysisTool() -> ChatCompletionRequest.Tool {
        FunctionBuilder()
            .withName("analyze_data")
            .withDescription("Perform statistical analysis on numerical data")
            .addArrayParameter(
                "data",
                itemType: .number,
                description: "Array of numerical values to analyze",
                required: true
            )
            .addParameter(
                "analysis_type",
                type: .string,
                description: "Type of analysis to perform",
                required: true,
                enumValues: ["mean", "median", "mode", "variance", "std_dev", "all"]
            )
            .addObjectParameter(
                "options",
                description: "Analysis options"
            ) { builder in
                builder
                    .addParameter(
                        "precision",
                        type: .integer,
                        description: "Decimal places for results",
                        defaultValue: 2
                    )
                    .addParameter(
                        "remove_outliers",
                        type: .boolean,
                        description: "Remove statistical outliers",
                        defaultValue: false
                    )
                    .addParameter(
                        "confidence_level",
                        type: .number,
                        description: "Confidence level for intervals (0-1)",
                        defaultValue: 0.95
                    )
            }
            .build()
    }
}

// MARK: - Interactive Builder UI

struct FunctionBuilderView: View {
    @State private var functionName = ""
    @State private var functionDescription = ""
    @State private var parameters: [ParameterDefinition] = []
    @State private var showingAddParameter = false
    @State private var generatedJSON = ""
    
    struct ParameterDefinition: Identifiable {
        let id = UUID()
        var name: String
        var type: FunctionBuilder.ParameterType
        var description: String
        var required: Bool
        var hasEnum: Bool
        var enumValues: String
        var hasDefault: Bool
        var defaultValue: String
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Function basics
                Section(header: Text("Function Details").font(.headline)) {
                    TextField("Function Name", text: $functionName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description", text: $functionDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Parameters
                Section(header: HStack {
                    Text("Parameters").font(.headline)
                    Spacer()
                    Button(action: { showingAddParameter = true }) {
                        Image(systemName: "plus.circle")
                    }
                }) {
                    if parameters.isEmpty {
                        Text("No parameters added yet")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(parameters) { param in
                            ParameterCard(parameter: param) {
                                parameters.removeAll { $0.id == param.id }
                            }
                        }
                    }
                }
                
                // Generate button
                Button(action: generateFunction) {
                    Text("Generate Function Tool")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(functionName.isEmpty)
                
                // Generated code
                if !generatedJSON.isEmpty {
                    Section(header: Text("Generated Tool").font(.headline)) {
                        Text(generatedJSON)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = generatedJSON
                                }) {
                                    Label("Copy", systemImage: "doc.on.clipboard")
                                }
                            }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Function Builder")
        .sheet(isPresented: $showingAddParameter) {
            AddParameterView { parameter in
                parameters.append(parameter)
            }
        }
    }
    
    private func generateFunction() {
        let builder = FunctionBuilder()
            .withName(functionName)
            .withDescription(functionDescription)
        
        for param in parameters {
            if param.hasEnum {
                let enumValues = param.enumValues
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                _ = builder.addParameter(
                    param.name,
                    type: param.type,
                    description: param.description.isEmpty ? nil : param.description,
                    required: param.required,
                    enumValues: enumValues.isEmpty ? nil : enumValues,
                    defaultValue: param.hasDefault ? param.defaultValue : nil
                )
            } else {
                _ = builder.addParameter(
                    param.name,
                    type: param.type,
                    description: param.description.isEmpty ? nil : param.description,
                    required: param.required,
                    defaultValue: param.hasDefault ? param.defaultValue : nil
                )
            }
        }
        
        let tool = builder.build()
        
        // Convert to JSON for display
        if let data = try? JSONEncoder().encode(tool),
           let json = String(data: data, encoding: .utf8) {
            generatedJSON = json
        }
    }
}

struct ParameterCard: View {
    let parameter: FunctionBuilderView.ParameterDefinition
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(parameter.name)
                    .font(.headline)
                
                if parameter.required {
                    Text("Required")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Label(parameter.type.rawValue, systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                if parameter.hasEnum {
                    Label("Enum", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if parameter.hasDefault {
                    Label("Default", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            if !parameter.description.isEmpty {
                Text(parameter.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AddParameterView: View {
    let onAdd: (FunctionBuilderView.ParameterDefinition) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var parameter = FunctionBuilderView.ParameterDefinition(
        name: "",
        type: .string,
        description: "",
        required: false,
        hasEnum: false,
        enumValues: "",
        hasDefault: false,
        defaultValue: ""
    )
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Parameter Name", text: $parameter.name)
                
                Picker("Type", selection: $parameter.type) {
                    ForEach([
                        FunctionBuilder.ParameterType.string,
                        .number,
                        .integer,
                        .boolean,
                        .array,
                        .object
                    ], id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                TextField("Description", text: $parameter.description)
                
                Toggle("Required", isOn: $parameter.required)
                
                Toggle("Has Enum Values", isOn: $parameter.hasEnum)
                
                if parameter.hasEnum {
                    TextField("Enum values (comma-separated)", text: $parameter.enumValues)
                }
                
                Toggle("Has Default Value", isOn: $parameter.hasDefault)
                
                if parameter.hasDefault {
                    TextField("Default Value", text: $parameter.defaultValue)
                }
            }
            .navigationTitle("Add Parameter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(parameter)
                        dismiss()
                    }
                    .disabled(parameter.name.isEmpty)
                }
            }
        }
    }
}