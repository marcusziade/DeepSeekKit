import SwiftUI
import DeepSeekKit

// Code analyzer with reasoning
struct CodeAnalyzerView: View {
    @StateObject private var analyzer = CodeAnalyzer()
    @State private var codeInput = ""
    @State private var analysisType: AnalysisType = .comprehensive
    @State private var language: ProgrammingLanguage = .swift
    
    enum AnalysisType: String, CaseIterable {
        case comprehensive = "Comprehensive"
        case performance = "Performance"
        case security = "Security"
        case maintainability = "Maintainability"
        case bugs = "Bug Detection"
        
        var icon: String {
            switch self {
            case .comprehensive: return "doc.text.magnifyingglass"
            case .performance: return "speedometer"
            case .security: return "lock.shield"
            case .maintainability: return "wrench.and.screwdriver"
            case .bugs: return "ant"
            }
        }
        
        var color: Color {
            switch self {
            case .comprehensive: return .blue
            case .performance: return .green
            case .security: return .red
            case .maintainability: return .orange
            case .bugs: return .purple
            }
        }
        
        var description: String {
            switch self {
            case .comprehensive: return "Complete code analysis"
            case .performance: return "Performance bottlenecks and optimizations"
            case .security: return "Security vulnerabilities and risks"
            case .maintainability: return "Code quality and maintainability"
            case .bugs: return "Potential bugs and issues"
            }
        }
    }
    
    enum ProgrammingLanguage: String, CaseIterable {
        case swift = "Swift"
        case python = "Python"
        case javascript = "JavaScript"
        case typescript = "TypeScript"
        case java = "Java"
        case go = "Go"
        case rust = "Rust"
        
        var fileExtension: String {
            switch self {
            case .swift: return ".swift"
            case .python: return ".py"
            case .javascript: return ".js"
            case .typescript: return ".ts"
            case .java: return ".java"
            case .go: return ".go"
            case .rust: return ".rs"
            }
        }
        
        var syntaxHighlighting: String {
            switch self {
            case .swift: return "swift"
            case .python: return "python"
            case .javascript, .typescript: return "javascript"
            case .java: return "java"
            case .go: return "go"
            case .rust: return "rust"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Code input
                CodeInputSection(
                    code: $codeInput,
                    language: $language,
                    onLoadExample: loadExampleCode
                )
                
                // Analysis options
                AnalysisOptionsSection(
                    analysisType: $analysisType,
                    language: $language
                )
                
                // Analyze button
                Button(action: performAnalysis) {
                    if analyzer.isAnalyzing {
                        HStack {
                            ProgressView()
                            Text("Analyzing...")
                        }
                    } else {
                        Label("Analyze Code", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(codeInput.isEmpty || analyzer.isAnalyzing)
                
                // Results
                if let analysis = analyzer.currentAnalysis {
                    AnalysisResultsView(analysis: analysis)
                }
                
                // History
                if !analyzer.analysisHistory.isEmpty {
                    AnalysisHistorySection(
                        history: analyzer.analysisHistory,
                        onSelect: { analyzer.currentAnalysis = $0 }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Code Analyzer")
    }
    
    private func performAnalysis() {
        Task {
            await analyzer.analyzeCode(
                codeInput,
                type: analysisType,
                language: language
            )
        }
    }
    
    private func loadExampleCode() {
        switch language {
        case .swift:
            codeInput = """
            func findDuplicates(_ nums: [Int]) -> [Int] {
                var seen = Set<Int>()
                var duplicates = [Int]()
                
                for num in nums {
                    if seen.contains(num) {
                        duplicates.append(num)
                    } else {
                        seen.insert(num)
                    }
                }
                
                return duplicates
            }
            """
        case .python:
            codeInput = """
            def find_duplicates(nums):
                seen = set()
                duplicates = []
                
                for num in nums:
                    if num in seen:
                        duplicates.append(num)
                    else:
                        seen.add(num)
                
                return duplicates
            """
        default:
            codeInput = "// Add your code here"
        }
    }
}

// MARK: - Code Analyzer Engine

class CodeAnalyzer: ObservableObject {
    @Published var currentAnalysis: CodeAnalysis?
    @Published var analysisHistory: [CodeAnalysis] = []
    @Published var isAnalyzing = false
    
    private let client: DeepSeekClient
    
    // MARK: - Models
    
    struct CodeAnalysis: Identifiable {
        let id = UUID()
        let code: String
        let language: CodeAnalyzerView.ProgrammingLanguage
        let type: CodeAnalyzerView.AnalysisType
        let timestamp: Date
        let summary: Summary
        let issues: [Issue]
        let suggestions: [Suggestion]
        let metrics: Metrics
        let reasoning: ReasoningContent
        
        struct Summary {
            let overview: String
            let score: Double // 0-100
            let grade: Grade
            let highlights: [String]
            let concerns: [String]
            
            enum Grade: String {
                case a = "A"
                case b = "B"
                case c = "C"
                case d = "D"
                case f = "F"
                
                var color: Color {
                    switch self {
                    case .a: return .green
                    case .b: return .blue
                    case .c: return .orange
                    case .d: return .red
                    case .f: return .red
                    }
                }
                
                static func from(score: Double) -> Grade {
                    switch score {
                    case 90...100: return .a
                    case 80..<90: return .b
                    case 70..<80: return .c
                    case 60..<70: return .d
                    default: return .f
                    }
                }
            }
        }
        
        struct Issue: Identifiable {
            let id = UUID()
            let severity: Severity
            let category: Category
            let title: String
            let description: String
            let line: Int?
            let column: Int?
            let codeSnippet: String?
            let fix: Fix?
            
            enum Severity {
                case critical, high, medium, low, info
                
                var color: Color {
                    switch self {
                    case .critical: return .red
                    case .high: return .orange
                    case .medium: return .yellow
                    case .low: return .blue
                    case .info: return .gray
                    }
                }
                
                var icon: String {
                    switch self {
                    case .critical: return "exclamationmark.triangle.fill"
                    case .high: return "exclamationmark.circle.fill"
                    case .medium: return "exclamationmark.circle"
                    case .low: return "info.circle"
                    case .info: return "info"
                    }
                }
            }
            
            enum Category {
                case performance, security, bug, style, complexity, memory
                
                var icon: String {
                    switch self {
                    case .performance: return "speedometer"
                    case .security: return "lock.trianglebadge.exclamationmark"
                    case .bug: return "ant"
                    case .style: return "paintbrush"
                    case .complexity: return "brain"
                    case .memory: return "memorychip"
                    }
                }
            }
            
            struct Fix {
                let description: String
                let code: String
                let explanation: String
            }
        }
        
        struct Suggestion: Identifiable {
            let id = UUID()
            let type: SuggestionType
            let title: String
            let description: String
            let impact: Impact
            let implementation: String?
            let example: String?
            
            enum SuggestionType {
                case refactoring, optimization, pattern, testing, documentation
                
                var icon: String {
                    switch self {
                    case .refactoring: return "arrow.triangle.2.circlepath"
                    case .optimization: return "bolt"
                    case .pattern: return "square.stack.3d.up"
                    case .testing: return "checkmark.shield"
                    case .documentation: return "doc.text"
                    }
                }
                
                var color: Color {
                    switch self {
                    case .refactoring: return .blue
                    case .optimization: return .green
                    case .pattern: return .purple
                    case .testing: return .orange
                    case .documentation: return .gray
                    }
                }
            }
            
            enum Impact {
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
        
        struct Metrics {
            let linesOfCode: Int
            let cyclomaticComplexity: Int
            let maintainabilityIndex: Double
            let technicalDebt: TimeInterval
            let testCoverage: Double?
            let duplicateCodeRatio: Double
            let commentRatio: Double
            
            struct ComplexityBreakdown {
                let functions: [(name: String, complexity: Int)]
                let classes: [(name: String, complexity: Int)]
            }
        }
        
        struct ReasoningContent {
            let raw: String
            let steps: [ReasoningStep]
            let patterns: [Pattern]
            let decisions: [Decision]
            
            struct ReasoningStep {
                let number: Int
                let action: String
                let analysis: String
                let findings: [String]
            }
            
            struct Pattern {
                let name: String
                let description: String
                let occurrences: Int
                let recommendation: String
            }
            
            struct Decision {
                let question: String
                let analysis: String
                let conclusion: String
                let confidence: Double
            }
        }
    }
    
    init(apiKey: String = "your-api-key") {
        self.client = DeepSeekClient(apiKey: apiKey)
        loadAnalysisHistory()
    }
    
    // MARK: - Analysis Methods
    
    @MainActor
    func analyzeCode(
        _ code: String,
        type: CodeAnalyzerView.AnalysisType,
        language: CodeAnalyzerView.ProgrammingLanguage
    ) async {
        isAnalyzing = true
        
        let prompt = createAnalysisPrompt(
            code: code,
            type: type,
            language: language
        )
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: """
                    You are an expert code analyzer. Analyze code thoroughly and provide
                    detailed insights with your reasoning process. Focus on:
                    1. Identifying issues and potential problems
                    2. Suggesting improvements
                    3. Calculating code metrics
                    4. Explaining your analysis step by step
                    """),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.3
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                let analysis = parseAnalysisResponse(
                    content: choice.message.content,
                    reasoning: choice.message.reasoningContent ?? "",
                    code: code,
                    type: type,
                    language: language
                )
                
                currentAnalysis = analysis
                analysisHistory.insert(analysis, at: 0)
                
                // Keep only last 10 analyses
                if analysisHistory.count > 10 {
                    analysisHistory.removeLast()
                }
                
                saveAnalysisHistory()
            }
        } catch {
            print("Analysis error: \(error)")
        }
        
        isAnalyzing = false
    }
    
    private func createAnalysisPrompt(
        code: String,
        type: CodeAnalyzerView.AnalysisType,
        language: CodeAnalyzerView.ProgrammingLanguage
    ) -> String {
        let typeSpecificPrompt: String
        
        switch type {
        case .comprehensive:
            typeSpecificPrompt = """
            Perform a comprehensive analysis covering:
            1. Code quality and style
            2. Performance characteristics
            3. Security vulnerabilities
            4. Maintainability concerns
            5. Potential bugs
            """
            
        case .performance:
            typeSpecificPrompt = """
            Focus on performance analysis:
            1. Time complexity analysis
            2. Space complexity analysis
            3. Performance bottlenecks
            4. Optimization opportunities
            5. Resource usage
            """
            
        case .security:
            typeSpecificPrompt = """
            Focus on security analysis:
            1. Security vulnerabilities
            2. Input validation issues
            3. Authentication/authorization problems
            4. Data exposure risks
            5. Best security practices
            """
            
        case .maintainability:
            typeSpecificPrompt = """
            Focus on maintainability:
            1. Code complexity
            2. Readability issues
            3. Coupling and cohesion
            4. Design patterns
            5. Technical debt
            """
            
        case .bugs:
            typeSpecificPrompt = """
            Focus on bug detection:
            1. Logic errors
            2. Edge cases not handled
            3. Null/nil reference issues
            4. Type mismatches
            5. Resource leaks
            """
        }
        
        return """
        Analyze this \(language.rawValue) code:
        
        ```\(language.syntaxHighlighting)
        \(code)
        ```
        
        \(typeSpecificPrompt)
        
        Provide:
        1. Summary with score (0-100) and grade
        2. Specific issues with severity and fixes
        3. Improvement suggestions
        4. Code metrics
        5. Your step-by-step reasoning
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseAnalysisResponse(
        content: String,
        reasoning: String,
        code: String,
        type: CodeAnalyzerView.AnalysisType,
        language: CodeAnalyzerView.ProgrammingLanguage
    ) -> CodeAnalysis {
        // Parse summary
        let summary = parseSummary(from: content)
        
        // Parse issues
        let issues = parseIssues(from: content, code: code)
        
        // Parse suggestions
        let suggestions = parseSuggestions(from: content)
        
        // Calculate metrics
        let metrics = calculateMetrics(code: code, content: content)
        
        // Parse reasoning
        let reasoningContent = parseReasoning(from: reasoning)
        
        return CodeAnalysis(
            code: code,
            language: language,
            type: type,
            timestamp: Date(),
            summary: summary,
            issues: issues,
            suggestions: suggestions,
            metrics: metrics,
            reasoning: reasoningContent
        )
    }
    
    private func parseSummary(from content: String) -> CodeAnalysis.Summary {
        var score = 75.0
        var highlights: [String] = []
        var concerns: [String] = []
        
        // Extract score
        if let scoreMatch = content.range(of: #"[Ss]core[:\s]+(\d+)"#, options: .regularExpression) {
            let scoreString = content[scoreMatch]
            if let extractedScore = Double(scoreString.filter { $0.isNumber }) {
                score = extractedScore
            }
        }
        
        // Extract highlights
        if content.lowercased().contains("good") || content.lowercased().contains("well") {
            highlights.append("Good code structure")
        }
        if content.lowercased().contains("efficient") {
            highlights.append("Efficient implementation")
        }
        if content.lowercased().contains("clear") {
            highlights.append("Clear and readable")
        }
        
        // Extract concerns
        if content.lowercased().contains("complex") {
            concerns.append("High complexity")
        }
        if content.lowercased().contains("performance") {
            concerns.append("Performance concerns")
        }
        if content.lowercased().contains("security") {
            concerns.append("Security considerations")
        }
        
        let grade = CodeAnalysis.Summary.Grade.from(score: score)
        
        return CodeAnalysis.Summary(
            overview: extractOverview(from: content),
            score: score,
            grade: grade,
            highlights: highlights.isEmpty ? ["No major highlights"] : highlights,
            concerns: concerns.isEmpty ? ["No major concerns"] : concerns
        )
    }
    
    private func extractOverview(from content: String) -> String {
        // Extract first paragraph or summary section
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if !line.isEmpty && !line.starts(with: "#") && !line.starts(with: "```") {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        return "Code analysis completed"
    }
    
    private func parseIssues(from content: String, code: String) -> [CodeAnalysis.Issue] {
        var issues: [CodeAnalysis.Issue] = []
        
        // Look for issue patterns
        let issuePatterns = [
            "issue", "problem", "error", "warning", "vulnerability",
            "bug", "defect", "flaw", "mistake"
        ]
        
        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            for pattern in issuePatterns {
                if lowercased.contains(pattern) {
                    let severity = determineSeverity(from: line)
                    let category = determineCategory(from: line)
                    
                    let issue = CodeAnalysis.Issue(
                        severity: severity,
                        category: category,
                        title: extractIssueTitle(from: line),
                        description: extractIssueDescription(from: lines, at: index),
                        line: extractLineNumber(from: line),
                        column: nil,
                        codeSnippet: extractCodeSnippet(from: lines, near: index),
                        fix: extractFix(from: lines, near: index)
                    )
                    
                    issues.append(issue)
                    break
                }
            }
        }
        
        return issues
    }
    
    private func parseSuggestions(from content: String) -> [CodeAnalysis.Suggestion] {
        var suggestions: [CodeAnalysis.Suggestion] = []
        
        let suggestionPatterns = [
            "suggest", "recommend", "consider", "improve",
            "optimize", "refactor", "enhance"
        ]
        
        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            for pattern in suggestionPatterns {
                if lowercased.contains(pattern) {
                    let type = determineSuggestionType(from: line)
                    let impact = determineSuggestionImpact(from: line)
                    
                    let suggestion = CodeAnalysis.Suggestion(
                        type: type,
                        title: extractSuggestionTitle(from: line),
                        description: extractSuggestionDescription(from: lines, at: index),
                        impact: impact,
                        implementation: extractImplementation(from: lines, near: index),
                        example: extractExample(from: lines, near: index)
                    )
                    
                    suggestions.append(suggestion)
                    break
                }
            }
        }
        
        return suggestions
    }
    
    private func calculateMetrics(code: String, content: String) -> CodeAnalysis.Metrics {
        let lines = code.components(separatedBy: .newlines)
        let linesOfCode = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        
        // Extract complexity from analysis
        var complexity = 1
        if let complexityMatch = content.range(of: #"[Cc]omplexity[:\s]+(\d+)"#, options: .regularExpression) {
            let complexityString = content[complexityMatch]
            complexity = Int(complexityString.filter { $0.isNumber }) ?? 1
        }
        
        // Calculate other metrics
        let commentLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).starts(with: "//") }.count
        let commentRatio = Double(commentLines) / Double(max(linesOfCode, 1))
        
        return CodeAnalysis.Metrics(
            linesOfCode: linesOfCode,
            cyclomaticComplexity: complexity,
            maintainabilityIndex: 70.0 + (commentRatio * 10), // Simplified
            technicalDebt: TimeInterval(complexity * 300), // 5 minutes per complexity point
            testCoverage: nil,
            duplicateCodeRatio: 0.0,
            commentRatio: commentRatio
        )
    }
    
    private func parseReasoning(from reasoning: String) -> CodeAnalysis.ReasoningContent {
        var steps: [CodeAnalysis.ReasoningContent.ReasoningStep] = []
        var patterns: [CodeAnalysis.ReasoningContent.Pattern] = []
        var decisions: [CodeAnalysis.ReasoningContent.Decision] = []
        
        // Parse reasoning steps
        let stepPattern = #"[Ss]tep\s*(\d+)[:\s]*(.*?)(?=[Ss]tep|\z)"#s
        if let regex = try? NSRegularExpression(pattern: stepPattern) {
            let matches = regex.matches(in: reasoning, range: NSRange(reasoning.startIndex..., in: reasoning))
            
            for match in matches {
                if let numberRange = Range(match.range(at: 1), in: reasoning),
                   let contentRange = Range(match.range(at: 2), in: reasoning) {
                    let number = Int(reasoning[numberRange]) ?? 0
                    let content = String(reasoning[contentRange])
                    
                    steps.append(CodeAnalysis.ReasoningContent.ReasoningStep(
                        number: number,
                        action: extractAction(from: content),
                        analysis: content,
                        findings: extractFindings(from: content)
                    ))
                }
            }
        }
        
        // Extract patterns
        if reasoning.lowercased().contains("pattern") {
            patterns.append(CodeAnalysis.ReasoningContent.Pattern(
                name: "Common Pattern",
                description: "Identified in code",
                occurrences: 1,
                recommendation: "Consider best practices"
            ))
        }
        
        // Extract decisions
        if reasoning.contains("?") {
            decisions.append(CodeAnalysis.ReasoningContent.Decision(
                question: "Analysis approach",
                analysis: "Considered multiple factors",
                conclusion: "Comprehensive analysis performed",
                confidence: 0.9
            ))
        }
        
        return CodeAnalysis.ReasoningContent(
            raw: reasoning,
            steps: steps,
            patterns: patterns,
            decisions: decisions
        )
    }
    
    // MARK: - Helper Methods
    
    private func determineSeverity(from line: String) -> CodeAnalysis.Issue.Severity {
        let lowercased = line.lowercased()
        
        if lowercased.contains("critical") || lowercased.contains("severe") {
            return .critical
        } else if lowercased.contains("high") || lowercased.contains("important") {
            return .high
        } else if lowercased.contains("medium") || lowercased.contains("moderate") {
            return .medium
        } else if lowercased.contains("low") || lowercased.contains("minor") {
            return .low
        }
        
        return .info
    }
    
    private func determineCategory(from line: String) -> CodeAnalysis.Issue.Category {
        let lowercased = line.lowercased()
        
        if lowercased.contains("performance") || lowercased.contains("speed") {
            return .performance
        } else if lowercased.contains("security") || lowercased.contains("vulnerability") {
            return .security
        } else if lowercased.contains("bug") || lowercased.contains("error") {
            return .bug
        } else if lowercased.contains("style") || lowercased.contains("format") {
            return .style
        } else if lowercased.contains("complex") {
            return .complexity
        } else if lowercased.contains("memory") || lowercased.contains("leak") {
            return .memory
        }
        
        return .bug
    }
    
    private func determineSuggestionType(from line: String) -> CodeAnalysis.Suggestion.SuggestionType {
        let lowercased = line.lowercased()
        
        if lowercased.contains("refactor") {
            return .refactoring
        } else if lowercased.contains("optimiz") {
            return .optimization
        } else if lowercased.contains("pattern") {
            return .pattern
        } else if lowercased.contains("test") {
            return .testing
        } else if lowercased.contains("document") || lowercased.contains("comment") {
            return .documentation
        }
        
        return .optimization
    }
    
    private func determineSuggestionImpact(from line: String) -> CodeAnalysis.Suggestion.Impact {
        let lowercased = line.lowercased()
        
        if lowercased.contains("significant") || lowercased.contains("major") {
            return .high
        } else if lowercased.contains("moderate") {
            return .medium
        }
        
        return .low
    }
    
    private func extractIssueTitle(from line: String) -> String {
        // Extract first few meaningful words
        let words = line.split(separator: " ").prefix(5)
        return words.joined(separator: " ")
    }
    
    private func extractIssueDescription(from lines: [String], at index: Int) -> String {
        // Get current line and possibly next line
        var description = lines[index]
        if index + 1 < lines.count {
            description += " " + lines[index + 1]
        }
        return description
    }
    
    private func extractLineNumber(from line: String) -> Int? {
        if let range = line.range(of: #"[Ll]ine\s*(\d+)"#, options: .regularExpression) {
            let lineString = line[range]
            return Int(lineString.filter { $0.isNumber })
        }
        return nil
    }
    
    private func extractCodeSnippet(from lines: [String], near index: Int) -> String? {
        // Look for code blocks near the issue
        for i in max(0, index - 2)..<min(lines.count, index + 3) {
            if lines[i].starts(with: "```") && i + 1 < lines.count {
                var snippet = ""
                for j in (i + 1)..<lines.count {
                    if lines[j].starts(with: "```") {
                        break
                    }
                    snippet += lines[j] + "\n"
                }
                return snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func extractFix(from lines: [String], near index: Int) -> CodeAnalysis.Issue.Fix? {
        // Look for fix suggestions
        for i in index..<min(lines.count, index + 5) {
            if lines[i].lowercased().contains("fix") || lines[i].lowercased().contains("solution") {
                return CodeAnalysis.Issue.Fix(
                    description: lines[i],
                    code: extractCodeSnippet(from: lines, near: i) ?? "",
                    explanation: "Apply this fix to resolve the issue"
                )
            }
        }
        return nil
    }
    
    private func extractSuggestionTitle(from line: String) -> String {
        let words = line.split(separator: " ").prefix(6)
        return words.joined(separator: " ")
    }
    
    private func extractSuggestionDescription(from lines: [String], at index: Int) -> String {
        var description = lines[index]
        if index + 1 < lines.count && !lines[index + 1].isEmpty {
            description += " " + lines[index + 1]
        }
        return description
    }
    
    private func extractImplementation(from lines: [String], near index: Int) -> String? {
        for i in index..<min(lines.count, index + 3) {
            if lines[i].lowercased().contains("implement") {
                return lines[i]
            }
        }
        return nil
    }
    
    private func extractExample(from lines: [String], near index: Int) -> String? {
        return extractCodeSnippet(from: lines, near: index)
    }
    
    private func extractAction(from content: String) -> String {
        let words = content.split(separator: " ").prefix(3)
        return words.joined(separator: " ")
    }
    
    private func extractFindings(from content: String) -> [String] {
        var findings: [String] = []
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if line.starts(with: "-") || line.starts(with: "•") {
                findings.append(line.dropFirst().trimmingCharacters(in: .whitespaces))
            }
        }
        
        return findings
    }
    
    // MARK: - Persistence
    
    private func loadAnalysisHistory() {
        // Load from storage
    }
    
    private func saveAnalysisHistory() {
        // Save to storage
    }
}

// MARK: - UI Components

struct CodeInputSection: View {
    @Binding var code: String
    @Binding var language: CodeAnalyzerView.ProgrammingLanguage
    let onLoadExample: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Code Input", systemImage: "doc.text")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    ForEach(CodeAnalyzerView.ProgrammingLanguage.allCases, id: \.self) { lang in
                        Button(action: { language = lang }) {
                            Label(lang.rawValue, systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                } label: {
                    HStack {
                        Text(language.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                }
                
                Button("Example", action: onLoadExample)
                    .font(.caption)
            }
            
            TextEditor(text: $code)
                .font(.system(.body, design: .monospaced))
                .frame(height: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            
            HStack {
                Text("\(code.components(separatedBy: .newlines).count) lines")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(language.fileExtension)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
    }
}

struct AnalysisOptionsSection: View {
    @Binding var analysisType: CodeAnalyzerView.AnalysisType
    @Binding var language: CodeAnalyzerView.ProgrammingLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Type")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(CodeAnalyzerView.AnalysisType.allCases, id: \.self) { type in
                    AnalysisTypeOption(
                        type: type,
                        isSelected: analysisType == type,
                        action: { analysisType = type }
                    )
                }
            }
        }
    }
}

struct AnalysisTypeOption: View {
    let type: CodeAnalyzerView.AnalysisType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundColor(isSelected ? .white : type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? type.color : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AnalysisResultsView: View {
    let analysis: CodeAnalyzer.CodeAnalysis
    @State private var selectedTab = 0
    @State private var showingReasoning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary card
            SummaryCard(summary: analysis.summary)
            
            // Metrics
            MetricsCard(metrics: analysis.metrics)
            
            // Tab view
            VStack(spacing: 0) {
                // Custom tab bar
                HStack(spacing: 0) {
                    TabButton(
                        title: "Issues (\(analysis.issues.count))",
                        icon: "exclamationmark.circle",
                        isSelected: selectedTab == 0,
                        action: { selectedTab = 0 }
                    )
                    
                    TabButton(
                        title: "Suggestions (\(analysis.suggestions.count))",
                        icon: "lightbulb",
                        isSelected: selectedTab == 1,
                        action: { selectedTab = 1 }
                    )
                    
                    TabButton(
                        title: "Reasoning",
                        icon: "brain",
                        isSelected: selectedTab == 2,
                        action: { selectedTab = 2 }
                    )
                }
                .background(Color(.systemGray6))
                
                // Tab content
                Group {
                    switch selectedTab {
                    case 0:
                        IssuesTab(issues: analysis.issues)
                    case 1:
                        SuggestionsTab(suggestions: analysis.suggestions)
                    case 2:
                        ReasoningTab(reasoning: analysis.reasoning)
                    default:
                        EmptyView()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .cornerRadius(8)
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.clear)
            .foregroundColor(isSelected ? .white : .secondary)
        }
    }
}

struct SummaryCard: View {
    let summary: CodeAnalyzer.CodeAnalysis.Summary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analysis Summary")
                        .font(.headline)
                    
                    Text(summary.overview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Grade badge
                ZStack {
                    Circle()
                        .fill(summary.grade.color)
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 0) {
                        Text(summary.grade.rawValue)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("\(Int(summary.score))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            // Highlights and concerns
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Highlights", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    ForEach(summary.highlights, id: \.self) { highlight in
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4, height: 4)
                            Text(highlight)
                                .font(.caption)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Concerns", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    ForEach(summary.concerns, id: \.self) { concern in
                        HStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 4, height: 4)
                            Text(concern)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MetricsCard: View {
    let metrics: CodeAnalyzer.CodeAnalysis.Metrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Code Metrics")
                .font(.caption)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                MetricItem(
                    label: "Lines",
                    value: "\(metrics.linesOfCode)",
                    icon: "doc.text"
                )
                
                MetricItem(
                    label: "Complexity",
                    value: "\(metrics.cyclomaticComplexity)",
                    icon: "brain"
                )
                
                MetricItem(
                    label: "Maintainability",
                    value: "\(Int(metrics.maintainabilityIndex))",
                    icon: "wrench"
                )
                
                MetricItem(
                    label: "Tech Debt",
                    value: formatTimeInterval(metrics.technicalDebt),
                    icon: "clock"
                )
                
                MetricItem(
                    label: "Comments",
                    value: "\(Int(metrics.commentRatio * 100))%",
                    icon: "text.bubble"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct MetricItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct IssuesTab: View {
    let issues: [CodeAnalyzer.CodeAnalysis.Issue]
    @State private var selectedSeverity: CodeAnalyzer.CodeAnalysis.Issue.Severity?
    
    var filteredIssues: [CodeAnalyzer.CodeAnalysis.Issue] {
        if let severity = selectedSeverity {
            return issues.filter { $0.severity == severity }
        }
        return issues
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Severity filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All (\(issues.count))",
                        isSelected: selectedSeverity == nil,
                        action: { selectedSeverity = nil }
                    )
                    
                    ForEach([
                        CodeAnalyzer.CodeAnalysis.Issue.Severity.critical,
                        .high, .medium, .low, .info
                    ], id: \.self) { severity in
                        let count = issues.filter { $0.severity == severity }.count
                        if count > 0 {
                            FilterChip(
                                title: "\(severityText(severity)) (\(count))",
                                color: severity.color,
                                isSelected: selectedSeverity == severity,
                                action: { selectedSeverity = severity }
                            )
                        }
                    }
                }
            }
            
            // Issues list
            if filteredIssues.isEmpty {
                NoItemsView(
                    icon: "checkmark.circle",
                    message: "No issues found",
                    color: .green
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredIssues) { issue in
                        IssueCard(issue: issue)
                    }
                }
            }
        }
    }
    
    private func severityText(_ severity: CodeAnalyzer.CodeAnalysis.Issue.Severity) -> String {
        switch severity {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .info: return "Info"
        }
    }
}

struct FilterChip: View {
    let title: String
    var color: Color = .blue
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

struct IssueCard: View {
    let issue: CodeAnalyzer.CodeAnalysis.Issue
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .top) {
                Image(systemName: issue.severity.icon)
                    .foregroundColor(issue.severity.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Label(issue.category.icon, systemImage: issue.category.icon)
                            .font(.caption2)
                        
                        if let line = issue.line {
                            Text("Line \(line)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            // Description
            Text(issue.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Code snippet
                    if let snippet = issue.codeSnippet {
                        Text("Code:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(snippet)
                            .font(.caption)
                            .fontFamily(.monospaced)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    // Fix
                    if let fix = issue.fix {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Suggested Fix", systemImage: "bandage")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            
                            Text(fix.description)
                                .font(.caption)
                            
                            if !fix.code.isEmpty {
                                Text(fix.code)
                                    .font(.caption)
                                    .fontFamily(.monospaced)
                                    .padding(8)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

struct SuggestionsTab: View {
    let suggestions: [CodeAnalyzer.CodeAnalysis.Suggestion]
    @State private var selectedType: CodeAnalyzer.CodeAnalysis.Suggestion.SuggestionType?
    
    var filteredSuggestions: [CodeAnalyzer.CodeAnalysis.Suggestion] {
        if let type = selectedType {
            return suggestions.filter { $0.type == type }
        }
        return suggestions
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All (\(suggestions.count))",
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )
                    
                    ForEach([
                        CodeAnalyzer.CodeAnalysis.Suggestion.SuggestionType.refactoring,
                        .optimization, .pattern, .testing, .documentation
                    ], id: \.self) { type in
                        let count = suggestions.filter { $0.type == type }.count
                        if count > 0 {
                            FilterChip(
                                title: "\(typeText(type)) (\(count))",
                                color: type.color,
                                isSelected: selectedType == type,
                                action: { selectedType = type }
                            )
                        }
                    }
                }
            }
            
            // Suggestions list
            if filteredSuggestions.isEmpty {
                NoItemsView(
                    icon: "lightbulb.slash",
                    message: "No suggestions",
                    color: .gray
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredSuggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion)
                    }
                }
            }
        }
    }
    
    private func typeText(_ type: CodeAnalyzer.CodeAnalysis.Suggestion.SuggestionType) -> String {
        switch type {
        case .refactoring: return "Refactor"
        case .optimization: return "Optimize"
        case .pattern: return "Pattern"
        case .testing: return "Testing"
        case .documentation: return "Docs"
        }
    }
}

struct SuggestionCard: View {
    let suggestion: CodeAnalyzer.CodeAnalysis.Suggestion
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .top) {
                Image(systemName: suggestion.type.icon)
                    .foregroundColor(suggestion.type.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        ImpactBadge(impact: suggestion.impact)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(typeText(suggestion.type))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            // Description
            Text(suggestion.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Implementation
                    if let implementation = suggestion.implementation {
                        Text("How to implement:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(implementation)
                            .font(.caption)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    // Example
                    if let example = suggestion.example {
                        Text("Example:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(example)
                            .font(.caption)
                            .fontFamily(.monospaced)
                            .padding(8)
                            .background(suggestion.type.color.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
    
    private func typeText(_ type: CodeAnalyzer.CodeAnalysis.Suggestion.SuggestionType) -> String {
        switch type {
        case .refactoring: return "Refactoring"
        case .optimization: return "Optimization"
        case .pattern: return "Design Pattern"
        case .testing: return "Testing"
        case .documentation: return "Documentation"
        }
    }
}

struct ImpactBadge: View {
    let impact: CodeAnalyzer.CodeAnalysis.Suggestion.Impact
    
    var text: String {
        switch impact {
        case .high: return "High Impact"
        case .medium: return "Medium Impact"
        case .low: return "Low Impact"
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(impact.color))
    }
}

struct ReasoningTab: View {
    let reasoning: CodeAnalyzer.CodeAnalysis.ReasoningContent
    @State private var selectedSection = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section selector
            Picker("Section", selection: $selectedSection) {
                Text("Steps (\(reasoning.steps.count))").tag(0)
                Text("Patterns (\(reasoning.patterns.count))").tag(1)
                Text("Decisions (\(reasoning.decisions.count))").tag(2)
                Text("Raw").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Content
            ScrollView {
                switch selectedSection {
                case 0:
                    ReasoningStepsView(steps: reasoning.steps)
                case 1:
                    PatternsView(patterns: reasoning.patterns)
                case 2:
                    DecisionsView(decisions: reasoning.decisions)
                case 3:
                    RawReasoningView(content: reasoning.raw)
                default:
                    EmptyView()
                }
            }
        }
    }
}

struct ReasoningStepsView: View {
    let steps: [CodeAnalyzer.CodeAnalysis.ReasoningContent.ReasoningStep]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(steps, id: \.number) { step in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Step \(step.number)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(step.action)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(step.analysis)
                        .font(.caption)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    
                    if !step.findings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Findings:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            ForEach(step.findings, id: \.self) { finding in
                                HStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 4, height: 4)
                                    Text(finding)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct PatternsView: View {
    let patterns: [CodeAnalyzer.CodeAnalysis.ReasoningContent.Pattern]
    
    var body: some View {
        if patterns.isEmpty {
            NoItemsView(
                icon: "square.stack.3d.up.slash",
                message: "No patterns detected",
                color: .gray
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(patterns, id: \.name) { pattern in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "square.stack.3d.up")
                                .foregroundColor(.purple)
                            
                            Text(pattern.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("\(pattern.occurrences)x")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(10)
                        }
                        
                        Text(pattern.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(pattern.recommendation, systemImage: "lightbulb")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct DecisionsView: View {
    let decisions: [CodeAnalyzer.CodeAnalysis.ReasoningContent.Decision]
    
    var body: some View {
        if decisions.isEmpty {
            NoItemsView(
                icon: "questionmark.circle",
                message: "No decisions recorded",
                color: .gray
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(decisions, id: \.question) { decision in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            
                            Text(decision.question)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Analysis:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(decision.analysis)
                            .font(.caption)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                        
                        HStack {
                            Label(decision.conclusion, systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            Text("Confidence: \(Int(decision.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct RawReasoningView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.caption)
                .fontFamily(.monospaced)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
    }
}

struct AnalysisHistorySection: View {
    let history: [CodeAnalyzer.CodeAnalysis]
    let onSelect: (CodeAnalyzer.CodeAnalysis) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis History")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(history) { analysis in
                        HistoryCard(
                            analysis: analysis,
                            onTap: { onSelect(analysis) }
                        )
                    }
                }
            }
        }
    }
}

struct HistoryCard: View {
    let analysis: CodeAnalyzer.CodeAnalysis
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: analysis.type.icon)
                        .foregroundColor(analysis.type.color)
                    
                    Text(analysis.type.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text(analysis.language.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(analysis.summary.grade.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(analysis.summary.grade.color)
                }
                
                Text("\(analysis.metrics.linesOfCode) lines")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(analysis.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 150)
            .background(Color(.systemGray6))
            .cornerRadius(8)
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
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

// MARK: - Demo

struct CodeAnalyzerDemo: View {
    var body: some View {
        CodeAnalyzerView()
    }
}