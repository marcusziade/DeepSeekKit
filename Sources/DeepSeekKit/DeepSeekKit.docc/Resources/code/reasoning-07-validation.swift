import SwiftUI
import DeepSeekKit

// Validate reasoning logic
struct ReasoningValidatorView: View {
    @StateObject private var validator = ReasoningValidator()
    @State private var inputReasoning = ""
    @State private var validationType: ValidationType = .logical
    @State private var showingResults = false
    
    enum ValidationType: String, CaseIterable {
        case logical = "Logical Consistency"
        case mathematical = "Mathematical Accuracy"
        case factual = "Factual Correctness"
        case complete = "Completeness Check"
        
        var icon: String {
            switch self {
            case .logical: return "brain"
            case .mathematical: return "function"
            case .factual: return "checkmark.seal"
            case .complete: return "list.bullet.rectangle"
            }
        }
        
        var color: Color {
            switch self {
            case .logical: return .purple
            case .mathematical: return .blue
            case .factual: return .green
            case .complete: return .orange
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Input section
                ReasoningInputSection(
                    reasoning: $inputReasoning,
                    title: "Reasoning to Validate"
                )
                
                // Validation type selector
                ValidationTypeSelector(
                    selectedType: $validationType
                )
                
                // Validation controls
                ValidationControls(
                    onValidate: performValidation,
                    onClear: clearResults,
                    isProcessing: validator.isValidating,
                    hasInput: !inputReasoning.isEmpty
                )
                
                // Results
                if let result = validator.currentResult {
                    ValidationResultsView(result: result)
                }
                
                // History
                if !validator.validationHistory.isEmpty {
                    ValidationHistorySection(
                        history: validator.validationHistory,
                        onSelect: { result in
                            validator.currentResult = result
                            showingResults = true
                        }
                    )
                }
                
                // Best practices
                BestPracticesSection()
            }
            .padding()
        }
        .navigationTitle("Reasoning Validator")
        .sheet(isPresented: $showingResults) {
            if let result = validator.currentResult {
                DetailedResultsView(result: result)
            }
        }
    }
    
    private func performValidation() {
        Task {
            await validator.validate(inputReasoning, type: validationType)
            showingResults = true
        }
    }
    
    private func clearResults() {
        inputReasoning = ""
        validator.currentResult = nil
    }
}

// MARK: - Reasoning Validator Engine

class ReasoningValidator: ObservableObject {
    @Published var currentResult: ValidationResult?
    @Published var validationHistory: [ValidationResult] = []
    @Published var isValidating = false
    
    private let client: DeepSeekClient
    
    // MARK: - Models
    
    struct ValidationResult: Identifiable {
        let id = UUID()
        let reasoning: String
        let type: ReasoningValidatorView.ValidationType
        let timestamp: Date
        let overallScore: Double
        let issues: [Issue]
        let strengths: [Strength]
        let suggestions: [Suggestion]
        let detailedAnalysis: DetailedAnalysis
        
        struct Issue: Identifiable {
            let id = UUID()
            let category: IssueCategory
            let description: String
            let severity: Severity
            let location: String?
            let fix: String?
            
            enum IssueCategory {
                case logicalFallacy
                case mathematicalError
                case factualInaccuracy
                case missingStep
                case contradiction
                case assumption
                
                var icon: String {
                    switch self {
                    case .logicalFallacy: return "exclamationmark.triangle"
                    case .mathematicalError: return "divide"
                    case .factualInaccuracy: return "xmark.circle"
                    case .missingStep: return "rectangle.badge.minus"
                    case .contradiction: return "arrow.triangle.swap"
                    case .assumption: return "questionmark.circle"
                    }
                }
            }
            
            enum Severity {
                case critical, major, minor, suggestion
                
                var color: Color {
                    switch self {
                    case .critical: return .red
                    case .major: return .orange
                    case .minor: return .yellow
                    case .suggestion: return .blue
                    }
                }
            }
        }
        
        struct Strength {
            let aspect: String
            let description: String
            let examples: [String]
        }
        
        struct Suggestion {
            let title: String
            let description: String
            let priority: Priority
            let implementation: String?
            
            enum Priority {
                case high, medium, low
                
                var color: Color {
                    switch self {
                    case .high: return .red
                    case .medium: return .orange
                    case .low: return .blue
                    }
                }
            }
        }
        
        struct DetailedAnalysis {
            let logicalFlow: FlowAnalysis
            let dependencies: [Dependency]
            let assumptions: [Assumption]
            let conclusions: [Conclusion]
            
            struct FlowAnalysis {
                let isCoherent: Bool
                let hasCircularReasoning: Bool
                let hasLogicalGaps: Bool
                let flowDiagram: [FlowNode]
                
                struct FlowNode {
                    let step: String
                    let connectsTo: [String]
                    let isValid: Bool
                }
            }
            
            struct Dependency {
                let step: String
                let dependsOn: [String]
                let isValid: Bool
                let reason: String?
            }
            
            struct Assumption {
                let content: String
                let isStated: Bool
                let isJustified: Bool
                let impact: String
            }
            
            struct Conclusion {
                let statement: String
                let isSupported: Bool
                let supportingSteps: [String]
                let confidence: Double
            }
        }
    }
    
    init(apiKey: String = "your-api-key") {
        self.client = DeepSeekClient(apiKey: apiKey)
        loadValidationHistory()
    }
    
    // MARK: - Validation Methods
    
    @MainActor
    func validate(_ reasoning: String, type: ReasoningValidatorView.ValidationType) async {
        isValidating = true
        
        let prompt = createValidationPrompt(for: reasoning, type: type)
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: """
                    You are an expert logic and reasoning validator. Analyze the given reasoning 
                    carefully and identify any issues, strengths, and areas for improvement.
                    Be thorough but constructive in your analysis.
                    """),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.3
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                let result = parseValidationResponse(
                    choice.message.content,
                    reasoning: reasoning,
                    type: type,
                    reasoningContent: choice.message.reasoningContent
                )
                
                currentResult = result
                validationHistory.insert(result, at: 0)
                
                // Keep only last 20 validations
                if validationHistory.count > 20 {
                    validationHistory.removeLast()
                }
                
                saveValidationHistory()
            }
        } catch {
            print("Validation error: \(error)")
        }
        
        isValidating = false
    }
    
    private func createValidationPrompt(for reasoning: String, type: ReasoningValidatorView.ValidationType) -> String {
        let basePrompt = """
        Analyze this reasoning process:
        
        ---
        \(reasoning)
        ---
        
        """
        
        switch type {
        case .logical:
            return basePrompt + """
            Perform a logical consistency check:
            1. Identify any logical fallacies
            2. Check for circular reasoning
            3. Verify that conclusions follow from premises
            4. Find any contradictions
            5. Assess the overall logical flow
            """
            
        case .mathematical:
            return basePrompt + """
            Validate mathematical accuracy:
            1. Check all calculations
            2. Verify formulas and equations
            3. Identify computational errors
            4. Validate mathematical reasoning
            5. Check unit consistency
            """
            
        case .factual:
            return basePrompt + """
            Verify factual correctness:
            1. Check stated facts
            2. Identify unsupported claims
            3. Verify data accuracy
            4. Check sources if mentioned
            5. Identify potential misinformation
            """
            
        case .complete:
            return basePrompt + """
            Check for completeness:
            1. Identify missing steps
            2. Find unstated assumptions
            3. Check if all cases are covered
            4. Verify edge cases are handled
            5. Assess overall thoroughness
            """
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseValidationResponse(
        _ content: String,
        reasoning: String,
        type: ReasoningValidatorView.ValidationType,
        reasoningContent: String?
    ) -> ValidationResult {
        // Parse issues
        let issues = extractIssues(from: content)
        
        // Parse strengths
        let strengths = extractStrengths(from: content)
        
        // Parse suggestions
        let suggestions = extractSuggestions(from: content)
        
        // Calculate score
        let score = calculateScore(issues: issues, strengths: strengths)
        
        // Create detailed analysis
        let analysis = createDetailedAnalysis(
            from: content,
            reasoning: reasoning,
            reasoningContent: reasoningContent
        )
        
        return ValidationResult(
            reasoning: reasoning,
            type: type,
            timestamp: Date(),
            overallScore: score,
            issues: issues,
            strengths: strengths,
            suggestions: suggestions,
            detailedAnalysis: analysis
        )
    }
    
    private func extractIssues(from content: String) -> [ValidationResult.Issue] {
        var issues: [ValidationResult.Issue] = []
        
        // Look for issue patterns
        let issuePatterns = [
            "error", "mistake", "incorrect", "wrong", "invalid",
            "fallacy", "contradiction", "missing", "unclear", "ambiguous"
        ]
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let lowercased = line.lowercased()
            
            for pattern in issuePatterns {
                if lowercased.contains(pattern) {
                    let category = determineIssueCategory(from: line)
                    let severity = determineSeverity(from: line)
                    
                    issues.append(ValidationResult.Issue(
                        category: category,
                        description: line.trimmingCharacters(in: .whitespaces),
                        severity: severity,
                        location: extractLocation(from: line),
                        fix: extractFix(from: lines, near: line)
                    ))
                    break
                }
            }
        }
        
        return issues
    }
    
    private func extractStrengths(from content: String) -> [ValidationResult.Strength] {
        var strengths: [ValidationResult.Strength] = []
        
        let strengthPatterns = [
            "correct", "valid", "sound", "clear", "thorough",
            "well", "good", "strong", "accurate", "precise"
        ]
        
        let lines = content.components(separatedBy: .newlines)
        var currentStrength: (aspect: String, description: String, examples: [String])?
        
        for line in lines {
            let lowercased = line.lowercased()
            
            for pattern in strengthPatterns {
                if lowercased.contains(pattern) {
                    if let strength = currentStrength {
                        strengths.append(ValidationResult.Strength(
                            aspect: strength.aspect,
                            description: strength.description,
                            examples: strength.examples
                        ))
                    }
                    
                    currentStrength = (
                        aspect: extractAspect(from: line),
                        description: line,
                        examples: []
                    )
                    break
                } else if currentStrength != nil && line.starts(with: "-") {
                    currentStrength?.examples.append(
                        line.dropFirst().trimmingCharacters(in: .whitespaces)
                    )
                }
            }
        }
        
        if let strength = currentStrength {
            strengths.append(ValidationResult.Strength(
                aspect: strength.aspect,
                description: strength.description,
                examples: strength.examples
            ))
        }
        
        return strengths
    }
    
    private func extractSuggestions(from content: String) -> [ValidationResult.Suggestion] {
        var suggestions: [ValidationResult.Suggestion] = []
        
        let suggestionPatterns = [
            "suggest", "recommend", "consider", "could", "should",
            "improve", "enhance", "better", "alternative"
        ]
        
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            for pattern in suggestionPatterns {
                if lowercased.contains(pattern) {
                    let priority = determinePriority(from: line)
                    let implementation = index < lines.count - 1 ? lines[index + 1] : nil
                    
                    suggestions.append(ValidationResult.Suggestion(
                        title: extractSuggestionTitle(from: line),
                        description: line,
                        priority: priority,
                        implementation: implementation
                    ))
                    break
                }
            }
        }
        
        return suggestions
    }
    
    // MARK: - Analysis Creation
    
    private func createDetailedAnalysis(
        from content: String,
        reasoning: String,
        reasoningContent: String?
    ) -> ValidationResult.DetailedAnalysis {
        // Create flow analysis
        let flowAnalysis = analyzeLogicalFlow(reasoning: reasoning, validation: content)
        
        // Extract dependencies
        let dependencies = extractDependencies(from: reasoning)
        
        // Extract assumptions
        let assumptions = extractAssumptions(from: reasoning, validation: content)
        
        // Extract conclusions
        let conclusions = extractConclusions(from: reasoning, validation: content)
        
        return ValidationResult.DetailedAnalysis(
            logicalFlow: flowAnalysis,
            dependencies: dependencies,
            assumptions: assumptions,
            conclusions: conclusions
        )
    }
    
    private func analyzeLogicalFlow(reasoning: String, validation: String) -> ValidationResult.DetailedAnalysis.FlowAnalysis {
        let hasCircular = validation.lowercased().contains("circular")
        let hasGaps = validation.lowercased().contains("gap") || validation.lowercased().contains("missing")
        let isCoherent = !hasCircular && !hasGaps && validation.lowercased().contains("coherent")
        
        // Create simplified flow diagram
        let steps = reasoning.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var flowNodes: [ValidationResult.DetailedAnalysis.FlowAnalysis.FlowNode] = []
        
        for (index, step) in steps.enumerated() {
            let connectsTo = index < steps.count - 1 ? ["Step \(index + 2)"] : []
            flowNodes.append(ValidationResult.DetailedAnalysis.FlowAnalysis.FlowNode(
                step: "Step \(index + 1): \(step.prefix(50))...",
                connectsTo: connectsTo,
                isValid: !validation.lowercased().contains("step \(index + 1)")
            ))
        }
        
        return ValidationResult.DetailedAnalysis.FlowAnalysis(
            isCoherent: isCoherent,
            hasCircularReasoning: hasCircular,
            hasLogicalGaps: hasGaps,
            flowDiagram: flowNodes
        )
    }
    
    private func extractDependencies(from reasoning: String) -> [ValidationResult.DetailedAnalysis.Dependency] {
        var dependencies: [ValidationResult.DetailedAnalysis.Dependency] = []
        
        let lines = reasoning.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.lowercased().contains("based on") ||
               line.lowercased().contains("from") ||
               line.lowercased().contains("using") {
                
                var dependsOn: [String] = []
                // Look for references to previous steps
                for i in 0..<index {
                    if line.lowercased().contains("step \(i + 1)") {
                        dependsOn.append("Step \(i + 1)")
                    }
                }
                
                if !dependsOn.isEmpty {
                    dependencies.append(ValidationResult.DetailedAnalysis.Dependency(
                        step: "Step \(index + 1)",
                        dependsOn: dependsOn,
                        isValid: true,
                        reason: nil
                    ))
                }
            }
        }
        
        return dependencies
    }
    
    private func extractAssumptions(from reasoning: String, validation: String) -> [ValidationResult.DetailedAnalysis.Assumption] {
        var assumptions: [ValidationResult.DetailedAnalysis.Assumption] = []
        
        let assumptionPatterns = ["assume", "given", "suppose", "let"]
        let lines = reasoning.components(separatedBy: .newlines)
        
        for line in lines {
            let lowercased = line.lowercased()
            
            for pattern in assumptionPatterns {
                if lowercased.contains(pattern) {
                    let isStated = true // Found in text
                    let isJustified = !validation.lowercased().contains("unjustified") &&
                                     !validation.lowercased().contains("unsupported")
                    
                    assumptions.append(ValidationResult.DetailedAnalysis.Assumption(
                        content: line.trimmingCharacters(in: .whitespaces),
                        isStated: isStated,
                        isJustified: isJustified,
                        impact: "Affects subsequent reasoning"
                    ))
                    break
                }
            }
        }
        
        return assumptions
    }
    
    private func extractConclusions(from reasoning: String, validation: String) -> [ValidationResult.DetailedAnalysis.Conclusion] {
        var conclusions: [ValidationResult.DetailedAnalysis.Conclusion] = []
        
        let conclusionPatterns = ["therefore", "thus", "hence", "conclude", "result", "answer"]
        let lines = reasoning.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            for pattern in conclusionPatterns {
                if lowercased.contains(pattern) {
                    let isSupported = !validation.lowercased().contains("unsupported conclusion")
                    let confidence = isSupported ? 0.8 : 0.4
                    
                    // Find supporting steps
                    var supportingSteps: [String] = []
                    for i in 0..<index {
                        supportingSteps.append("Step \(i + 1)")
                    }
                    
                    conclusions.append(ValidationResult.DetailedAnalysis.Conclusion(
                        statement: line.trimmingCharacters(in: .whitespaces),
                        isSupported: isSupported,
                        supportingSteps: supportingSteps,
                        confidence: confidence
                    ))
                    break
                }
            }
        }
        
        return conclusions
    }
    
    // MARK: - Helper Methods
    
    private func determineIssueCategory(from line: String) -> ValidationResult.Issue.IssueCategory {
        let lowercased = line.lowercased()
        
        if lowercased.contains("fallacy") { return .logicalFallacy }
        if lowercased.contains("calculation") || lowercased.contains("math") { return .mathematicalError }
        if lowercased.contains("fact") || lowercased.contains("incorrect") { return .factualInaccuracy }
        if lowercased.contains("missing") { return .missingStep }
        if lowercased.contains("contradict") { return .contradiction }
        if lowercased.contains("assum") { return .assumption }
        
        return .logicalFallacy
    }
    
    private func determineSeverity(from line: String) -> ValidationResult.Issue.Severity {
        let lowercased = line.lowercased()
        
        if lowercased.contains("critical") || lowercased.contains("serious") { return .critical }
        if lowercased.contains("major") || lowercased.contains("significant") { return .major }
        if lowercased.contains("minor") || lowercased.contains("small") { return .minor }
        
        return .suggestion
    }
    
    private func determinePriority(from line: String) -> ValidationResult.Suggestion.Priority {
        let lowercased = line.lowercased()
        
        if lowercased.contains("important") || lowercased.contains("critical") { return .high }
        if lowercased.contains("consider") || lowercased.contains("might") { return .low }
        
        return .medium
    }
    
    private func extractLocation(from line: String) -> String? {
        if let range = line.range(of: #"step\s+\d+"#, options: .regularExpression) {
            return String(line[range])
        }
        return nil
    }
    
    private func extractFix(from lines: [String], near line: String) -> String? {
        if let index = lines.firstIndex(of: line),
           index < lines.count - 1,
           lines[index + 1].lowercased().contains("fix") ||
           lines[index + 1].lowercased().contains("correct") {
            return lines[index + 1]
        }
        return nil
    }
    
    private func extractAspect(from line: String) -> String {
        if line.lowercased().contains("logic") { return "Logical Structure" }
        if line.lowercased().contains("math") { return "Mathematical Accuracy" }
        if line.lowercased().contains("clear") { return "Clarity" }
        if line.lowercased().contains("complete") { return "Completeness" }
        
        return "General"
    }
    
    private func extractSuggestionTitle(from line: String) -> String {
        // Extract first few words as title
        let words = line.split(separator: " ").prefix(5)
        return words.joined(separator: " ")
    }
    
    private func calculateScore(issues: [ValidationResult.Issue], strengths: [ValidationResult.Strength]) -> Double {
        let baseScore = 1.0
        
        // Deduct for issues
        var deduction = 0.0
        for issue in issues {
            switch issue.severity {
            case .critical: deduction += 0.3
            case .major: deduction += 0.2
            case .minor: deduction += 0.1
            case .suggestion: deduction += 0.05
            }
        }
        
        // Add for strengths
        let strengthBonus = Double(strengths.count) * 0.05
        
        return max(0, min(1, baseScore - deduction + strengthBonus))
    }
    
    // MARK: - Persistence
    
    private func loadValidationHistory() {
        // Load from UserDefaults or persistent storage
    }
    
    private func saveValidationHistory() {
        // Save to UserDefaults or persistent storage
    }
}

// MARK: - UI Components

struct ReasoningInputSection: View {
    @Binding var reasoning: String
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "text.alignleft")
                .font(.headline)
            
            TextEditor(text: $reasoning)
                .font(.body)
                .frame(height: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            HStack {
                Text("\(reasoning.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Paste Example") {
                    reasoning = exampleReasoning
                }
                .font(.caption)
            }
        }
    }
    
    private var exampleReasoning: String {
        """
        Step 1: Given that x + 2y = 10
        Step 2: And y = 3
        Step 3: Substituting y = 3 into the equation: x + 2(3) = 10
        Step 4: This gives us x + 6 = 10
        Step 5: Therefore x = 4
        Step 6: Let's verify: 4 + 2(3) = 4 + 6 = 10 ✓
        """
    }
}

struct ValidationTypeSelector: View {
    @Binding var selectedType: ReasoningValidatorView.ValidationType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Validation Type")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ReasoningValidatorView.ValidationType.allCases, id: \.self) { type in
                    ValidationTypeCard(
                        type: type,
                        isSelected: selectedType == type,
                        action: { selectedType = type }
                    )
                }
            }
        }
    }
}

struct ValidationTypeCard: View {
    let type: ReasoningValidatorView.ValidationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : type.color)
                
                Text(type.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color : Color(.systemGray6))
            )
        }
    }
}

struct ValidationControls: View {
    let onValidate: () -> Void
    let onClear: () -> Void
    let isProcessing: Bool
    let hasInput: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onValidate) {
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Validating...")
                    }
                } else {
                    Label("Validate", systemImage: "checkmark.shield")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasInput || isProcessing)
            
            Button(action: onClear) {
                Label("Clear", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!hasInput || isProcessing)
        }
    }
}

struct ValidationResultsView: View {
    let result: ReasoningValidator.ValidationResult
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Score card
            ScoreCard(score: result.overallScore)
            
            // Tab selector
            Picker("Results", selection: $selectedTab) {
                Text("Issues (\(result.issues.count))").tag(0)
                Text("Strengths (\(result.strengths.count))").tag(1)
                Text("Suggestions (\(result.suggestions.count))").tag(2)
                Text("Analysis").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Tab content
            switch selectedTab {
            case 0:
                IssuesTab(issues: result.issues)
            case 1:
                StrengthsTab(strengths: result.strengths)
            case 2:
                SuggestionsTab(suggestions: result.suggestions)
            case 3:
                AnalysisTab(analysis: result.detailedAnalysis)
            default:
                EmptyView()
            }
        }
    }
}

struct ScoreCard: View {
    let score: Double
    
    var scoreColor: Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .orange }
        return .red
    }
    
    var scoreLabel: String {
        if score >= 0.8 { return "Excellent" }
        if score >= 0.6 { return "Good" }
        if score >= 0.4 { return "Fair" }
        return "Needs Improvement"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Score")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(scoreLabel)
                    .font(.headline)
            }
            
            Spacer()
            
            CircularProgressView(
                progress: score,
                color: scoreColor,
                lineWidth: 8
            )
            .frame(width: 60, height: 60)
            .overlay(
                Text("\(Int(score * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.5), color]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

struct IssuesTab: View {
    let issues: [ReasoningValidator.ValidationResult.Issue]
    
    var body: some View {
        if issues.isEmpty {
            NoItemsView(
                icon: "checkmark.seal.fill",
                message: "No issues found!",
                color: .green
            )
        } else {
            VStack(spacing: 8) {
                ForEach(issues) { issue in
                    IssueCard(issue: issue)
                }
            }
        }
    }
}

struct IssueCard: View {
    let issue: ReasoningValidator.ValidationResult.Issue
    @State private var showingFix = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: issue.category.icon)
                    .foregroundColor(issue.severity.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.description)
                        .font(.subheadline)
                    
                    if let location = issue.location {
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        SeverityBadge(severity: issue.severity)
                        
                        Spacer()
                        
                        if issue.fix != nil {
                            Button(action: { showingFix.toggle() }) {
                                Text(showingFix ? "Hide Fix" : "Show Fix")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            
            if showingFix, let fix = issue.fix {
                Text(fix)
                    .font(.caption)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SeverityBadge: View {
    let severity: ReasoningValidator.ValidationResult.Issue.Severity
    
    var text: String {
        switch severity {
        case .critical: return "Critical"
        case .major: return "Major"
        case .minor: return "Minor"
        case .suggestion: return "Suggestion"
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(severity.color))
    }
}

struct StrengthsTab: View {
    let strengths: [ReasoningValidator.ValidationResult.Strength]
    
    var body: some View {
        if strengths.isEmpty {
            NoItemsView(
                icon: "star.slash",
                message: "No specific strengths identified",
                color: .gray
            )
        } else {
            VStack(spacing: 8) {
                ForEach(strengths.indices, id: \.self) { index in
                    StrengthCard(strength: strengths[index])
                }
            }
        }
    }
}

struct StrengthCard: View {
    let strength: ReasoningValidator.ValidationResult.Strength
    @State private var showingExamples = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(strength.aspect)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(strength.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !strength.examples.isEmpty {
                    Button(action: { showingExamples.toggle() }) {
                        Image(systemName: showingExamples ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
            }
            
            if showingExamples {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Examples:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    ForEach(strength.examples, id: \.self) { example in
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                            Text(example)
                        }
                        .font(.caption2)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SuggestionsTab: View {
    let suggestions: [ReasoningValidator.ValidationResult.Suggestion]
    
    var body: some View {
        if suggestions.isEmpty {
            NoItemsView(
                icon: "lightbulb.slash",
                message: "No suggestions at this time",
                color: .gray
            )
        } else {
            VStack(spacing: 8) {
                ForEach(suggestions.indices, id: \.self) { index in
                    SuggestionCard(suggestion: suggestions[index])
                }
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: ReasoningValidator.ValidationResult.Suggestion
    @State private var showingImplementation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(suggestion.priority.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        PriorityBadge(priority: suggestion.priority)
                        
                        Spacer()
                        
                        if suggestion.implementation != nil {
                            Button(action: { showingImplementation.toggle() }) {
                                Text(showingImplementation ? "Hide Details" : "Show Details")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            
            if showingImplementation, let implementation = suggestion.implementation {
                Text(implementation)
                    .font(.caption)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PriorityBadge: View {
    let priority: ReasoningValidator.ValidationResult.Suggestion.Priority
    
    var text: String {
        switch priority {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(priority.color))
    }
}

struct AnalysisTab: View {
    let analysis: ReasoningValidator.ValidationResult.DetailedAnalysis
    @State private var selectedSection = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Analysis", selection: $selectedSection) {
                Text("Flow").tag(0)
                Text("Dependencies").tag(1)
                Text("Assumptions").tag(2)
                Text("Conclusions").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            switch selectedSection {
            case 0:
                FlowAnalysisView(flow: analysis.logicalFlow)
            case 1:
                DependenciesView(dependencies: analysis.dependencies)
            case 2:
                AssumptionsView(assumptions: analysis.assumptions)
            case 3:
                ConclusionsView(conclusions: analysis.conclusions)
            default:
                EmptyView()
            }
        }
    }
}

struct FlowAnalysisView: View {
    let flow: ReasoningValidator.ValidationResult.DetailedAnalysis.FlowAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Summary
            HStack(spacing: 16) {
                FlowIndicator(
                    label: "Coherent",
                    isValid: flow.isCoherent,
                    icon: "checkmark.circle"
                )
                
                FlowIndicator(
                    label: "No Circular",
                    isValid: !flow.hasCircularReasoning,
                    icon: "arrow.triangle.2.circlepath"
                )
                
                FlowIndicator(
                    label: "No Gaps",
                    isValid: !flow.hasLogicalGaps,
                    icon: "rectangle.split.3x1"
                )
            }
            
            // Flow diagram
            if !flow.flowDiagram.isEmpty {
                Text("Flow Diagram")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(flow.flowDiagram.indices, id: \.self) { index in
                        FlowNodeView(node: flow.flowDiagram[index])
                        
                        if index < flow.flowDiagram.count - 1 {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }
}

struct FlowIndicator: View {
    let label: String
    let isValid: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isValid ? .green : .red)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

struct FlowNodeView: View {
    let node: ReasoningValidator.ValidationResult.DetailedAnalysis.FlowAnalysis.FlowNode
    
    var body: some View {
        HStack {
            Circle()
                .fill(node.isValid ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(node.step)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct DependenciesView: View {
    let dependencies: [ReasoningValidator.ValidationResult.DetailedAnalysis.Dependency]
    
    var body: some View {
        if dependencies.isEmpty {
            NoItemsView(
                icon: "link.circle.fill",
                message: "No dependencies found",
                color: .gray
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(dependencies.indices, id: \.self) { index in
                    DependencyRow(dependency: dependencies[index])
                }
            }
        }
    }
}

struct DependencyRow: View {
    let dependency: ReasoningValidator.ValidationResult.DetailedAnalysis.Dependency
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: dependency.isValid ? "link.circle.fill" : "link.circle")
                .foregroundColor(dependency.isValid ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dependency.step)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("Depends on: \(dependency.dependsOn.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let reason = dependency.reason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
}

struct AssumptionsView: View {
    let assumptions: [ReasoningValidator.ValidationResult.DetailedAnalysis.Assumption]
    
    var body: some View {
        if assumptions.isEmpty {
            NoItemsView(
                icon: "questionmark.circle",
                message: "No assumptions identified",
                color: .gray
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(assumptions.indices, id: \.self) { index in
                    AssumptionCard(assumption: assumptions[index])
                }
            }
        }
    }
}

struct AssumptionCard: View {
    let assumption: ReasoningValidator.ValidationResult.DetailedAnalysis.Assumption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
                
                Text(assumption.content)
                    .font(.caption)
                    .lineLimit(2)
            }
            
            HStack(spacing: 12) {
                Label(
                    assumption.isStated ? "Stated" : "Implicit",
                    systemImage: assumption.isStated ? "checkmark" : "xmark"
                )
                .font(.caption2)
                .foregroundColor(assumption.isStated ? .green : .orange)
                
                Label(
                    assumption.isJustified ? "Justified" : "Unjustified",
                    systemImage: assumption.isJustified ? "checkmark" : "xmark"
                )
                .font(.caption2)
                .foregroundColor(assumption.isJustified ? .green : .red)
            }
            
            Text("Impact: \(assumption.impact)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ConclusionsView: View {
    let conclusions: [ReasoningValidator.ValidationResult.DetailedAnalysis.Conclusion]
    
    var body: some View {
        if conclusions.isEmpty {
            NoItemsView(
                icon: "flag.slash",
                message: "No conclusions found",
                color: .gray
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(conclusions.indices, id: \.self) { index in
                    ConclusionCard(conclusion: conclusions[index])
                }
            }
        }
    }
}

struct ConclusionCard: View {
    let conclusion: ReasoningValidator.ValidationResult.DetailedAnalysis.Conclusion
    @State private var showingSupport = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "flag.checkered")
                    .foregroundColor(conclusion.isSupported ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(conclusion.statement)
                        .font(.caption)
                        .lineLimit(2)
                    
                    HStack {
                        Label(
                            conclusion.isSupported ? "Supported" : "Unsupported",
                            systemImage: conclusion.isSupported ? "checkmark.seal" : "xmark.seal"
                        )
                        .font(.caption2)
                        .foregroundColor(conclusion.isSupported ? .green : .red)
                        
                        Spacer()
                        
                        Text("Confidence: \(Int(conclusion.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !conclusion.supportingSteps.isEmpty {
                Button(action: { showingSupport.toggle() }) {
                    HStack {
                        Text("Supporting steps")
                            .font(.caption2)
                        Image(systemName: showingSupport ? "chevron.up" : "chevron.down")
                    }
                }
                
                if showingSupport {
                    Text(conclusion.supportingSteps.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ValidationHistorySection: View {
    let history: [ReasoningValidator.ValidationResult]
    let onSelect: (ReasoningValidator.ValidationResult) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Validation History")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(history) { result in
                        HistoryCard(
                            result: result,
                            onTap: { onSelect(result) }
                        )
                    }
                }
            }
        }
    }
}

struct HistoryCard: View {
    let result: ReasoningValidator.ValidationResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: result.type.icon)
                        .foregroundColor(result.type.color)
                    
                    Text(result.type.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    CircularProgressView(
                        progress: result.overallScore,
                        color: scoreColor(result.overallScore),
                        lineWidth: 4
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(Int(result.overallScore * 100))")
                            .font(.caption2)
                            .fontWeight(.bold)
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(result.issues.count) issues")
                            .font(.caption2)
                            .foregroundColor(.red)
                        
                        Text("\(result.strengths.count) strengths")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                
                Text(result.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 150)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .orange }
        return .red
    }
}

struct BestPracticesSection: View {
    @State private var isExpanded = false
    
    let practices = [
        ("Clear Premises", "State all assumptions and given information clearly at the beginning"),
        ("Logical Flow", "Ensure each step follows logically from previous ones"),
        ("Explicit Connections", "Make connections between steps explicit"),
        ("Verify Calculations", "Double-check all mathematical operations"),
        ("Consider Edge Cases", "Think about boundary conditions and special cases"),
        ("State Conclusions", "Clearly state final conclusions and how they were reached")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Label("Best Practices", systemImage: "star.circle")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(practices, id: \.0) { practice in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(practice.0)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text(practice.1)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct DetailedResultsView: View {
    let result: ReasoningValidator.ValidationResult
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Original reasoning
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original Reasoning")
                            .font(.headline)
                        
                        Text(result.reasoning)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Full results
                    ValidationResultsView(result: result)
                }
                .padding()
            }
            .navigationTitle("Detailed Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct NoItemsView: View {
    let icon: String
    let message: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Demo

struct ReasoningValidatorDemo: View {
    var body: some View {
        ReasoningValidatorView()
    }
}