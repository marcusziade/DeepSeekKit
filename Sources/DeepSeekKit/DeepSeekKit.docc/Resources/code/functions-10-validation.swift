import SwiftUI
import DeepSeekKit

// Parameter validation for function calls
struct ParameterValidator {
    
    // MARK: - Validation Rules
    
    struct ValidationRule {
        let name: String
        let description: String
        let validate: (Any?) -> ValidationResult
    }
    
    enum ValidationResult {
        case valid
        case invalid(reason: String)
        case warning(message: String)
        
        var isValid: Bool {
            switch self {
            case .valid, .warning:
                return true
            case .invalid:
                return false
            }
        }
    }
    
    // MARK: - Common Validators
    
    static func required() -> ValidationRule {
        ValidationRule(
            name: "Required",
            description: "Parameter must be provided"
        ) { value in
            if value == nil {
                return .invalid(reason: "Parameter is required")
            }
            
            if let string = value as? String, string.isEmpty {
                return .invalid(reason: "Parameter cannot be empty")
            }
            
            if let array = value as? [Any], array.isEmpty {
                return .warning(message: "Array is empty")
            }
            
            return .valid
        }
    }
    
    static func type<T>(_ type: T.Type) -> ValidationRule {
        ValidationRule(
            name: "Type(\(type))",
            description: "Parameter must be of type \(type)"
        ) { value in
            guard let value = value else {
                return .valid // nil is handled by required validator
            }
            
            if value is T {
                return .valid
            }
            
            return .invalid(reason: "Expected type \(type), got \(Swift.type(of: value))")
        }
    }
    
    static func range<T: Comparable>(_ range: ClosedRange<T>) -> ValidationRule {
        ValidationRule(
            name: "Range",
            description: "Value must be within \(range)"
        ) { value in
            guard let value = value as? T else {
                return .valid // Type validation handled separately
            }
            
            if range.contains(value) {
                return .valid
            }
            
            return .invalid(reason: "Value \(value) is outside allowed range \(range)")
        }
    }
    
    static func minLength(_ length: Int) -> ValidationRule {
        ValidationRule(
            name: "MinLength(\(length))",
            description: "Minimum length of \(length)"
        ) { value in
            if let string = value as? String {
                return string.count >= length ? .valid : 
                    .invalid(reason: "String must be at least \(length) characters")
            }
            
            if let array = value as? [Any] {
                return array.count >= length ? .valid :
                    .invalid(reason: "Array must have at least \(length) items")
            }
            
            return .valid
        }
    }
    
    static func maxLength(_ length: Int) -> ValidationRule {
        ValidationRule(
            name: "MaxLength(\(length))",
            description: "Maximum length of \(length)"
        ) { value in
            if let string = value as? String {
                return string.count <= length ? .valid :
                    .invalid(reason: "String must not exceed \(length) characters")
            }
            
            if let array = value as? [Any] {
                return array.count <= length ? .valid :
                    .invalid(reason: "Array must not exceed \(length) items")
            }
            
            return .valid
        }
    }
    
    static func pattern(_ regex: String) -> ValidationRule {
        ValidationRule(
            name: "Pattern",
            description: "Must match pattern: \(regex)"
        ) { value in
            guard let string = value as? String else {
                return .valid
            }
            
            do {
                let regex = try NSRegularExpression(pattern: regex)
                let range = NSRange(location: 0, length: string.utf16.count)
                
                if regex.firstMatch(in: string, range: range) != nil {
                    return .valid
                } else {
                    return .invalid(reason: "Does not match required pattern")
                }
            } catch {
                return .warning(message: "Invalid regex pattern")
            }
        }
    }
    
    static func oneOf<T: Equatable>(_ values: [T]) -> ValidationRule {
        ValidationRule(
            name: "OneOf",
            description: "Must be one of: \(values)"
        ) { value in
            guard let value = value as? T else {
                return .valid
            }
            
            if values.contains(value) {
                return .valid
            }
            
            return .invalid(reason: "Value must be one of: \(values)")
        }
    }
    
    static func custom(_ name: String, validate: @escaping (Any?) -> ValidationResult) -> ValidationRule {
        ValidationRule(
            name: name,
            description: "Custom validation",
            validate: validate
        )
    }
}

// MARK: - Parameter Schema

struct ParameterSchema {
    let name: String
    let type: ParameterType
    let description: String?
    let rules: [ParameterValidator.ValidationRule]
    let defaultValue: Any?
    
    enum ParameterType {
        case string
        case number
        case integer
        case boolean
        case array(elementType: ParameterType)
        case object(properties: [String: ParameterSchema])
        
        var swiftType: Any.Type {
            switch self {
            case .string: return String.self
            case .number: return Double.self
            case .integer: return Int.self
            case .boolean: return Bool.self
            case .array: return [Any].self
            case .object: return [String: Any].self
            }
        }
    }
    
    func validate(_ value: Any?) -> ParameterValidator.ValidationResult {
        // Check type first
        if let value = value {
            switch type {
            case .string:
                guard value is String else {
                    return .invalid(reason: "Expected string")
                }
            case .number:
                guard value is Double || value is Int else {
                    return .invalid(reason: "Expected number")
                }
            case .integer:
                guard value is Int else {
                    return .invalid(reason: "Expected integer")
                }
            case .boolean:
                guard value is Bool else {
                    return .invalid(reason: "Expected boolean")
                }
            case .array(let elementType):
                guard let array = value as? [Any] else {
                    return .invalid(reason: "Expected array")
                }
                // Validate each element
                for (index, element) in array.enumerated() {
                    let elementSchema = ParameterSchema(
                        name: "\(name)[\(index)]",
                        type: elementType,
                        description: nil,
                        rules: [],
                        defaultValue: nil
                    )
                    let result = elementSchema.validate(element)
                    if case .invalid = result {
                        return result
                    }
                }
            case .object(let properties):
                guard let object = value as? [String: Any] else {
                    return .invalid(reason: "Expected object")
                }
                // Validate each property
                for (key, schema) in properties {
                    let result = schema.validate(object[key])
                    if case .invalid = result {
                        return result
                    }
                }
            }
        }
        
        // Apply validation rules
        for rule in rules {
            let result = rule.validate(value)
            if case .invalid = result {
                return result
            }
        }
        
        return .valid
    }
}

// MARK: - Function Validator

class FunctionValidator: ObservableObject {
    @Published var validationResults: [ValidationEntry] = []
    
    struct ValidationEntry: Identifiable {
        let id = UUID()
        let functionName: String
        let parameterName: String
        let value: Any?
        let result: ParameterValidator.ValidationResult
        let timestamp: Date
    }
    
    private var functionSchemas: [String: [ParameterSchema]] = [:]
    
    init() {
        registerBuiltInSchemas()
    }
    
    private func registerBuiltInSchemas() {
        // Weather function
        functionSchemas["get_weather"] = [
            ParameterSchema(
                name: "location",
                type: .string,
                description: "City and state/country",
                rules: [
                    ParameterValidator.required(),
                    ParameterValidator.minLength(3),
                    ParameterValidator.pattern("^[A-Za-z\\s,]+$")
                ],
                defaultValue: nil
            ),
            ParameterSchema(
                name: "units",
                type: .string,
                description: "Temperature units",
                rules: [
                    ParameterValidator.oneOf(["celsius", "fahrenheit", "kelvin"])
                ],
                defaultValue: "fahrenheit"
            )
        ]
        
        // Email function
        functionSchemas["send_email"] = [
            ParameterSchema(
                name: "to",
                type: .string,
                description: "Recipient email",
                rules: [
                    ParameterValidator.required(),
                    ParameterValidator.pattern("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$")
                ],
                defaultValue: nil
            ),
            ParameterSchema(
                name: "subject",
                type: .string,
                description: "Email subject",
                rules: [
                    ParameterValidator.required(),
                    ParameterValidator.minLength(1),
                    ParameterValidator.maxLength(200)
                ],
                defaultValue: nil
            ),
            ParameterSchema(
                name: "body",
                type: .string,
                description: "Email body",
                rules: [
                    ParameterValidator.required(),
                    ParameterValidator.minLength(1),
                    ParameterValidator.maxLength(10000)
                ],
                defaultValue: nil
            ),
            ParameterSchema(
                name: "attachments",
                type: .array(elementType: .string),
                description: "File paths",
                rules: [
                    ParameterValidator.custom("Valid paths") { value in
                        guard let paths = value as? [String] else { return .valid }
                        
                        for path in paths {
                            if !FileManager.default.fileExists(atPath: path) {
                                return .warning(message: "File not found: \(path)")
                            }
                        }
                        
                        return .valid
                    }
                ],
                defaultValue: []
            )
        ]
        
        // Data processing function
        functionSchemas["analyze_data"] = [
            ParameterSchema(
                name: "data",
                type: .array(elementType: .number),
                description: "Numerical data",
                rules: [
                    ParameterValidator.required(),
                    ParameterValidator.minLength(1),
                    ParameterValidator.custom("Valid numbers") { value in
                        guard let numbers = value as? [Any] else { return .valid }
                        
                        for num in numbers {
                            if !(num is Double || num is Int) {
                                return .invalid(reason: "All elements must be numbers")
                            }
                        }
                        
                        return .valid
                    }
                ],
                defaultValue: nil
            ),
            ParameterSchema(
                name: "options",
                type: .object(properties: [
                    "precision": ParameterSchema(
                        name: "precision",
                        type: .integer,
                        description: "Decimal places",
                        rules: [
                            ParameterValidator.range(0...10)
                        ],
                        defaultValue: 2
                    ),
                    "remove_outliers": ParameterSchema(
                        name: "remove_outliers",
                        type: .boolean,
                        description: "Remove outliers",
                        rules: [],
                        defaultValue: false
                    )
                ]),
                description: "Analysis options",
                rules: [],
                defaultValue: [:]
            )
        ]
    }
    
    func validateFunctionCall(_ toolCall: ChatCompletionResponse.Choice.Message.ToolCall) -> Bool {
        let functionName = toolCall.function.name
        
        guard let schemas = functionSchemas[functionName] else {
            // Unknown function - can't validate
            return true
        }
        
        // Parse arguments
        guard let data = toolCall.function.arguments.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            validationResults.append(ValidationEntry(
                functionName: functionName,
                parameterName: "arguments",
                value: nil,
                result: .invalid(reason: "Invalid JSON arguments"),
                timestamp: Date()
            ))
            return false
        }
        
        var allValid = true
        
        // Validate each parameter
        for schema in schemas {
            let value = arguments[schema.name] ?? schema.defaultValue
            let result = schema.validate(value)
            
            validationResults.append(ValidationEntry(
                functionName: functionName,
                parameterName: schema.name,
                value: value,
                result: result,
                timestamp: Date()
            ))
            
            if case .invalid = result {
                allValid = false
            }
        }
        
        return allValid
    }
}

// MARK: - Validation UI

struct FunctionValidationView: View {
    @StateObject private var validator = FunctionValidator()
    @State private var testFunctionName = "get_weather"
    @State private var testArguments = """
    {
        "location": "San Francisco, CA",
        "units": "fahrenheit"
    }
    """
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Test input
            VStack(alignment: .leading) {
                Text("Test Function Call")
                    .font(.headline)
                
                Picker("Function", selection: $testFunctionName) {
                    Text("get_weather").tag("get_weather")
                    Text("send_email").tag("send_email")
                    Text("analyze_data").tag("analyze_data")
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Text("Arguments (JSON):")
                    .font(.subheadline)
                
                TextEditor(text: $testArguments)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button("Validate") {
                    validateTestFunction()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Validation results
            ValidationResultsView(results: validator.validationResults)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Parameter Validation")
    }
    
    private func validateTestFunction() {
        // Create mock tool call
        let toolCall = ChatCompletionResponse.Choice.Message.ToolCall(
            id: "test",
            type: .function,
            function: ChatCompletionResponse.Choice.Message.ToolCall.Function(
                name: testFunctionName,
                arguments: testArguments
            )
        )
        
        _ = validator.validateFunctionCall(toolCall)
    }
}

struct ValidationResultsView: View {
    let results: [FunctionValidator.ValidationEntry]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Validation Results")
                .font(.headline)
            
            if results.isEmpty {
                Text("No validation results yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(results.reversed()) { entry in
                            ValidationResultRow(entry: entry)
                        }
                    }
                }
            }
        }
    }
}

struct ValidationResultRow: View {
    let entry: FunctionValidator.ValidationEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text("\(entry.functionName).\(entry.parameterName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(messageColor)
            
            if let value = entry.value {
                Text("Value: \(String(describing: value))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(8)
    }
    
    private var icon: String {
        switch entry.result {
        case .valid:
            return "checkmark.circle.fill"
        case .invalid:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var color: Color {
        switch entry.result {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .warning:
            return .orange
        }
    }
    
    private var backgroundColor: Color {
        switch entry.result {
        case .valid:
            return Color.green.opacity(0.1)
        case .invalid:
            return Color.red.opacity(0.1)
        case .warning:
            return Color.orange.opacity(0.1)
        }
    }
    
    private var message: String {
        switch entry.result {
        case .valid:
            return "Valid"
        case .invalid(let reason):
            return reason
        case .warning(let message):
            return message
        }
    }
    
    private var messageColor: Color {
        switch entry.result {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .warning:
            return .orange
        }
    }
}

// MARK: - Live Validation Example

struct LiveValidationExample: View {
    @State private var location = ""
    @State private var units = "fahrenheit"
    @State private var validationMessage = ""
    @State private var isValid = false
    
    let weatherSchema = ParameterSchema(
        name: "location",
        type: .string,
        description: "City and state/country",
        rules: [
            ParameterValidator.required(),
            ParameterValidator.minLength(3),
            ParameterValidator.pattern("^[A-Za-z\\s,]+$")
        ],
        defaultValue: nil
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Validation Example")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.subheadline)
                
                TextField("Enter city, state/country", text: $location)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: location) { _ in
                        validateLocation()
                    }
                
                HStack {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isValid ? .green : .red)
                    
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(isValid ? .green : .red)
                }
            }
            
            Picker("Units", selection: $units) {
                Text("Fahrenheit").tag("fahrenheit")
                Text("Celsius").tag("celsius")
                Text("Kelvin").tag("kelvin")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button("Submit") {
                // Process valid input
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            validateLocation()
        }
    }
    
    private func validateLocation() {
        let result = weatherSchema.validate(location.isEmpty ? nil : location)
        
        switch result {
        case .valid:
            isValid = true
            validationMessage = "Valid location"
        case .invalid(let reason):
            isValid = false
            validationMessage = reason
        case .warning(let message):
            isValid = true
            validationMessage = message
        }
    }
}