import SwiftUI
import DeepSeekKit

// Analyze reasoning patterns
struct ReasoningAnalysisView: View {
    @StateObject private var analyzer = ReasoningAnalyzer()
    @State private var inputCode = """
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
    @State private var analysisType: AnalysisType = .complexity
    @State private var isAnalyzing = false
    
    enum AnalysisType: String, CaseIterable {
        case complexity = "Complexity Analysis"
        case optimization = "Optimization"
        case bugs = "Bug Detection"
        case patterns = "Pattern Analysis"
        
        var icon: String {
            switch self {
            case .complexity: return "speedometer"
            case .optimization: return "bolt.fill"
            case .bugs: return "ant.fill"
            case .patterns: return "square.stack.3d.up"
            }
        }
        
        var color: Color {
            switch self {
            case .complexity: return .blue
            case .optimization: return .green
            case .bugs: return .red
            case .patterns: return .purple
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Code input
                CodeInputSection(
                    code: $inputCode,
                    title: "Code to Analyze"
                )
                
                // Analysis type selector
                AnalysisTypeSelector(
                    selectedType: $analysisType
                )
                
                // Analyze button
                Button(action: performAnalysis) {
                    if isAnalyzing {
                        HStack {
                            ProgressView()
                            Text("Analyzing...")
                        }
                    } else {
                        Label("Analyze Code", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputCode.isEmpty || isAnalyzing)
                
                // Results
                if let analysis = analyzer.currentAnalysis {
                    AnalysisResultsView(
                        analysis: analysis,
                        type: analysisType
                    )
                }
                
                // History
                if !analyzer.analysisHistory.isEmpty {
                    AnalysisHistorySection(
                        history: analyzer.analysisHistory
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Reasoning Analysis")
    }
    
    private func performAnalysis() {
        Task {
            isAnalyzing = true
            await analyzer.analyze(code: inputCode, type: analysisType)
            isAnalyzing = false
        }
    }
}

// MARK: - Reasoning Analyzer

class ReasoningAnalyzer: ObservableObject {
    @Published var currentAnalysis: Analysis?
    @Published var analysisHistory: [Analysis] = []
    
    private let client: DeepSeekClient
    
    struct Analysis: Identifiable {
        let id = UUID()
        let code: String
        let type: ReasoningAnalysisView.AnalysisType
        let timestamp: Date
        let reasoning: ReasoningContent
        let result: AnalysisResult
        
        struct ReasoningContent {
            let raw: String
            let steps: [ReasoningStep]
            let insights: [Insight]
            
            struct ReasoningStep {
                let number: Int
                let description: String
                let details: String
            }
            
            struct Insight {
                let category: String
                let description: String
                let severity: Severity
                
                enum Severity {
                    case info, warning, critical
                    
                    var color: Color {
                        switch self {
                        case .info: return .blue
                        case .warning: return .orange
                        case .critical: return .red
                        }
                    }
                }
            }
        }
        
        enum AnalysisResult {
            case complexity(time: String, space: String, explanation: String)
            case optimization(suggestions: [Suggestion], improvedCode: String?)
            case bugs(issues: [Issue], fixes: [Fix])
            case patterns(detected: [Pattern], recommendations: [String])
            
            struct Suggestion {
                let title: String
                let description: String
                let impact: String
                let code: String?
            }
            
            struct Issue {
                let line: Int?
                let description: String
                let severity: String
            }
            
            struct Fix {
                let issue: String
                let solution: String
                let code: String
            }
            
            struct Pattern {
                let name: String
                let description: String
                let pros: [String]
                let cons: [String]
            }
        }
    }
    
    init(apiKey: String = "your-api-key") {
        self.client = DeepSeekClient(apiKey: apiKey)
    }
    
    @MainActor
    func analyze(code: String, type: ReasoningAnalysisView.AnalysisType) async {
        let prompt = createPrompt(for: type, code: code)
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: """
                    You are an expert code analyzer. Analyze the provided code and show your 
                    reasoning process step by step. Be thorough but concise.
                    """),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.3
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                let reasoning = parseReasoning(choice.message.reasoningContent ?? "")
                let result = parseResult(choice.message.content, type: type)
                
                let analysis = Analysis(
                    code: code,
                    type: type,
                    timestamp: Date(),
                    reasoning: reasoning,
                    result: result
                )
                
                currentAnalysis = analysis
                analysisHistory.insert(analysis, at: 0)
                
                // Keep only last 10 analyses
                if analysisHistory.count > 10 {
                    analysisHistory.removeLast()
                }
            }
        } catch {
            print("Analysis error: \(error)")
        }
    }
    
    private func createPrompt(for type: ReasoningAnalysisView.AnalysisType, code: String) -> String {
        switch type {
        case .complexity:
            return """
            Analyze the time and space complexity of this code:
            
            ```swift
            \(code)
            ```
            
            Provide:
            1. Time complexity in Big O notation
            2. Space complexity in Big O notation
            3. Detailed explanation of your analysis
            """
            
        case .optimization:
            return """
            Optimize this code for better performance:
            
            ```swift
            \(code)
            ```
            
            Provide:
            1. Performance bottlenecks
            2. Optimization suggestions
            3. Improved code if applicable
            """
            
        case .bugs:
            return """
            Find potential bugs and issues in this code:
            
            ```swift
            \(code)
            ```
            
            Identify:
            1. Logic errors
            2. Edge cases not handled
            3. Potential runtime errors
            4. Suggested fixes
            """
            
        case .patterns:
            return """
            Analyze the design patterns and code structure:
            
            ```swift
            \(code)
            ```
            
            Identify:
            1. Design patterns used
            2. Code structure analysis
            3. Best practices followed/violated
            4. Recommendations
            """
        }
    }
    
    private func parseReasoning(_ content: String) -> Analysis.ReasoningContent {
        var steps: [Analysis.ReasoningContent.ReasoningStep] = []
        var insights: [Analysis.ReasoningContent.Insight] = []
        
        // Parse steps
        let stepPattern = #"(?:Step|STEP)\s*(\d+)[:\s]*(.*?)(?=Step|STEP|\z)"#s
        if let regex = try? NSRegularExpression(pattern: stepPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                if let numberRange = Range(match.range(at: 1), in: content),
                   let descRange = Range(match.range(at: 2), in: content) {
                    let number = Int(content[numberRange]) ?? 0
                    let fullText = String(content[descRange])
                    let lines = fullText.split(separator: "\n", maxSplits: 1)
                    
                    steps.append(Analysis.ReasoningContent.ReasoningStep(
                        number: number,
                        description: String(lines.first ?? ""),
                        details: lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    ))
                }
            }
        }
        
        // Extract insights
        let insightKeywords = ["important", "note", "warning", "critical", "issue", "problem"]
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let lowercased = line.lowercased()
            if insightKeywords.contains(where: lowercased.contains) {
                let severity: Analysis.ReasoningContent.Insight.Severity
                if lowercased.contains("critical") || lowercased.contains("error") {
                    severity = .critical
                } else if lowercased.contains("warning") || lowercased.contains("issue") {
                    severity = .warning
                } else {
                    severity = .info
                }
                
                insights.append(Analysis.ReasoningContent.Insight(
                    category: "Analysis",
                    description: line.trimmingCharacters(in: .whitespaces),
                    severity: severity
                ))
            }
        }
        
        return Analysis.ReasoningContent(
            raw: content,
            steps: steps,
            insights: insights
        )
    }
    
    private func parseResult(_ content: String, type: ReasoningAnalysisView.AnalysisType) -> Analysis.AnalysisResult {
        switch type {
        case .complexity:
            return parseComplexityResult(content)
        case .optimization:
            return parseOptimizationResult(content)
        case .bugs:
            return parseBugsResult(content)
        case .patterns:
            return parsePatternsResult(content)
        }
    }
    
    private func parseComplexityResult(_ content: String) -> Analysis.AnalysisResult {
        // Extract complexity from response
        var timeComplexity = "O(?)"
        var spaceComplexity = "O(?)"
        
        if let timeMatch = content.range(of: #"[Tt]ime\s*[Cc]omplexity[:\s]*O\([^)]+\)"#, options: .regularExpression) {
            timeComplexity = String(content[timeMatch]).components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "O(?)"
        }
        
        if let spaceMatch = content.range(of: #"[Ss]pace\s*[Cc]omplexity[:\s]*O\([^)]+\)"#, options: .regularExpression) {
            spaceComplexity = String(content[spaceMatch]).components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "O(?)"
        }
        
        return .complexity(
            time: timeComplexity,
            space: spaceComplexity,
            explanation: content
        )
    }
    
    private func parseOptimizationResult(_ content: String) -> Analysis.AnalysisResult {
        var suggestions: [Analysis.AnalysisResult.Suggestion] = []
        
        // Extract suggestions (simplified parsing)
        let lines = content.components(separatedBy: .newlines)
        var currentSuggestion: (title: String, description: String, impact: String, code: String?) = ("", "", "", nil)
        
        for line in lines {
            if line.starts(with: "1.") || line.starts(with: "2.") || line.starts(with: "3.") {
                if !currentSuggestion.title.isEmpty {
                    suggestions.append(Analysis.AnalysisResult.Suggestion(
                        title: currentSuggestion.title,
                        description: currentSuggestion.description,
                        impact: currentSuggestion.impact,
                        code: currentSuggestion.code
                    ))
                }
                currentSuggestion = (line, "", "Performance improvement", nil)
            } else if !currentSuggestion.title.isEmpty {
                currentSuggestion.description += line + "\n"
            }
        }
        
        // Add last suggestion
        if !currentSuggestion.title.isEmpty {
            suggestions.append(Analysis.AnalysisResult.Suggestion(
                title: currentSuggestion.title,
                description: currentSuggestion.description,
                impact: currentSuggestion.impact,
                code: currentSuggestion.code
            ))
        }
        
        // Extract improved code if present
        var improvedCode: String?
        if let codeStart = content.range(of: "```swift")?.upperBound,
           let codeEnd = content.range(of: "```", range: codeStart..<content.endIndex)?.lowerBound {
            improvedCode = String(content[codeStart..<codeEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return .optimization(suggestions: suggestions, improvedCode: improvedCode)
    }
    
    private func parseBugsResult(_ content: String) -> Analysis.AnalysisResult {
        var issues: [Analysis.AnalysisResult.Issue] = []
        var fixes: [Analysis.AnalysisResult.Fix] = []
        
        // Simplified parsing
        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.lowercased().contains("issue") || line.lowercased().contains("bug") {
                issues.append(Analysis.AnalysisResult.Issue(
                    line: nil,
                    description: line,
                    severity: line.lowercased().contains("critical") ? "critical" : "warning"
                ))
            }
            
            if line.lowercased().contains("fix") || line.lowercased().contains("solution") {
                fixes.append(Analysis.AnalysisResult.Fix(
                    issue: issues.last?.description ?? "Unknown issue",
                    solution: line,
                    code: ""
                ))
            }
        }
        
        return .bugs(issues: issues, fixes: fixes)
    }
    
    private func parsePatternsResult(_ content: String) -> Analysis.AnalysisResult {
        var patterns: [Analysis.AnalysisResult.Pattern] = []
        
        // Detect common patterns
        if content.lowercased().contains("set") && content.lowercased().contains("duplicate") {
            patterns.append(Analysis.AnalysisResult.Pattern(
                name: "Set-based Deduplication",
                description: "Using a Set to track seen elements for efficient duplicate detection",
                pros: ["O(1) lookup time", "Memory efficient for unique elements"],
                cons: ["Additional memory required", "Order might not be preserved"]
            ))
        }
        
        let recommendations = [
            "Consider using functional approaches for cleaner code",
            "Add input validation for edge cases",
            "Consider generic implementation for reusability"
        ]
        
        return .patterns(detected: patterns, recommendations: recommendations)
    }
}

// MARK: - UI Components

struct CodeInputSection: View {
    @Binding var code: String
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "doc.text")
                .font(.headline)
            
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
        }
    }
}

struct AnalysisTypeSelector: View {
    @Binding var selectedType: ReasoningAnalysisView.AnalysisType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Type")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ReasoningAnalysisView.AnalysisType.allCases, id: \.self) { type in
                    AnalysisTypeCard(
                        type: type,
                        isSelected: selectedType == type,
                        action: { selectedType = type }
                    )
                }
            }
        }
    }
}

struct AnalysisTypeCard: View {
    let type: ReasoningAnalysisView.AnalysisType
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
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color : Color(.systemGray6))
            )
        }
    }
}

struct AnalysisResultsView: View {
    let analysis: ReasoningAnalyzer.Analysis
    let type: ReasoningAnalysisView.AnalysisType
    @State private var showingReasoning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Analysis Results", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(analysis.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Reasoning toggle
            Button(action: { showingReasoning.toggle() }) {
                HStack {
                    Label(
                        showingReasoning ? "Hide Reasoning" : "Show Reasoning",
                        systemImage: showingReasoning ? "eye.slash" : "eye"
                    )
                    Spacer()
                    Image(systemName: showingReasoning ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            
            if showingReasoning {
                ReasoningContentDisplay(reasoning: analysis.reasoning)
            }
            
            // Result display
            ResultDisplay(result: analysis.result)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ReasoningContentDisplay: View {
    let reasoning: ReasoningAnalyzer.Analysis.ReasoningContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Steps
            if !reasoning.steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reasoning Steps")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(reasoning.steps, id: \.number) { step in
                        ReasoningStepView(step: step)
                    }
                }
            }
            
            // Insights
            if !reasoning.insights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Insights")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(reasoning.insights, id: \.description) { insight in
                        InsightView(insight: insight)
                    }
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ReasoningStepView: View {
    let step: ReasoningAnalyzer.Analysis.ReasoningContent.ReasoningStep
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !step.details.isEmpty {
                    Text(step.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct InsightView: View {
    let insight: ReasoningAnalyzer.Analysis.ReasoningContent.Insight
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(insight.severity.color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            Text(insight.description)
                .font(.caption)
        }
    }
}

struct ResultDisplay: View {
    let result: ReasoningAnalyzer.Analysis.AnalysisResult
    
    var body: some View {
        switch result {
        case .complexity(let time, let space, let explanation):
            ComplexityResultView(time: time, space: space, explanation: explanation)
            
        case .optimization(let suggestions, let improvedCode):
            OptimizationResultView(suggestions: suggestions, improvedCode: improvedCode)
            
        case .bugs(let issues, let fixes):
            BugsResultView(issues: issues, fixes: fixes)
            
        case .patterns(let detected, let recommendations):
            PatternsResultView(patterns: detected, recommendations: recommendations)
        }
    }
}

struct ComplexityResultView: View {
    let time: String
    let space: String
    let explanation: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                ComplexityBadge(label: "Time", value: time, color: .blue)
                ComplexityBadge(label: "Space", value: space, color: .green)
            }
            
            Text("Explanation")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(explanation)
                .font(.caption)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
    }
}

struct ComplexityBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct OptimizationResultView: View {
    let suggestions: [ReasoningAnalyzer.Analysis.AnalysisResult.Suggestion]
    let improvedCode: String?
    @State private var showingCode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization Suggestions")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(suggestions.indices, id: \.self) { index in
                SuggestionCard(suggestion: suggestions[index], number: index + 1)
            }
            
            if improvedCode != nil {
                Button(action: { showingCode.toggle() }) {
                    Label(
                        showingCode ? "Hide Improved Code" : "Show Improved Code",
                        systemImage: "doc.text.magnifyingglass"
                    )
                }
                .buttonStyle(.bordered)
                
                if showingCode, let code = improvedCode {
                    ScrollView(.horizontal) {
                        Text(code)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: ReasoningAnalyzer.Analysis.AnalysisResult.Suggestion
    let number: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.green))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(suggestion.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct BugsResultView: View {
    let issues: [ReasoningAnalyzer.Analysis.AnalysisResult.Issue]
    let fixes: [ReasoningAnalyzer.Analysis.AnalysisResult.Fix]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !issues.isEmpty {
                Text("Issues Found")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(issues.indices, id: \.self) { index in
                    IssueRow(issue: issues[index])
                }
            }
            
            if !fixes.isEmpty {
                Text("Suggested Fixes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                ForEach(fixes.indices, id: \.self) { index in
                    FixRow(fix: fixes[index])
                }
            }
        }
    }
}

struct IssueRow: View {
    let issue: ReasoningAnalyzer.Analysis.AnalysisResult.Issue
    
    var severityColor: Color {
        switch issue.severity.lowercased() {
        case "critical": return .red
        case "warning": return .orange
        default: return .yellow
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(severityColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.description)
                    .font(.caption)
                
                if let line = issue.line {
                    Text("Line \(line)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct FixRow: View {
    let fix: ReasoningAnalyzer.Analysis.AnalysisResult.Fix
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bandage.fill")
                .font(.caption)
                .foregroundColor(.green)
            
            Text(fix.solution)
                .font(.caption)
        }
    }
}

struct PatternsResultView: View {
    let patterns: [ReasoningAnalyzer.Analysis.AnalysisResult.Pattern]
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !patterns.isEmpty {
                Text("Detected Patterns")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(patterns, id: \.name) { pattern in
                    PatternCard(pattern: pattern)
                }
            }
            
            if !recommendations.isEmpty {
                Text("Recommendations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                ForEach(recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text(recommendation)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct PatternCard: View {
    let pattern: ReasoningAnalyzer.Analysis.AnalysisResult.Pattern
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading) {
                        Text(pattern.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(pattern.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pros")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        ForEach(pattern.pros, id: \.self) { pro in
                            HStack(alignment: .top, spacing: 4) {
                                Text("•")
                                Text(pro)
                            }
                            .font(.caption2)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cons")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        ForEach(pattern.cons, id: \.self) { con in
                            HStack(alignment: .top, spacing: 4) {
                                Text("•")
                                Text(con)
                            }
                            .font(.caption2)
                        }
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

struct AnalysisHistorySection: View {
    let history: [ReasoningAnalyzer.Analysis]
    @State private var selectedAnalysis: ReasoningAnalyzer.Analysis?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis History")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(history) { analysis in
                        HistoryCard(
                            analysis: analysis,
                            isSelected: selectedAnalysis?.id == analysis.id,
                            action: { selectedAnalysis = analysis }
                        )
                    }
                }
            }
        }
    }
}

struct HistoryCard: View {
    let analysis: ReasoningAnalyzer.Analysis
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: analysis.type.icon)
                        .font(.caption)
                        .foregroundColor(analysis.type.color)
                    
                    Text(analysis.type.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                
                Text(analysis.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(String(analysis.code.prefix(50)) + "...")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(width: 150)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Demo

struct ReasoningAnalysisDemo: View {
    let apiKey: String
    
    var body: some View {
        ReasoningAnalysisView()
    }
}