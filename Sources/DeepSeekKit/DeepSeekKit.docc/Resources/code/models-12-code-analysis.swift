import SwiftUI
import DeepSeekKit

struct ReasonerExample: View {
    @StateObject private var client = DeepSeekClient()
    @State private var codeInput = """
    func fibonacci(_ n: Int) -> Int {
        if n <= 1 {
            return n
        }
        return fibonacci(n - 1) + fibonacci(n - 2)
    }
    """
    @State private var analysis: CodeAnalysis?
    @State private var isLoading = false
    @State private var selectedAnalysisType = AnalysisType.general
    
    enum AnalysisType: String, CaseIterable {
        case general = "General Analysis"
        case performance = "Performance Review"
        case security = "Security Check"
        case refactor = "Refactoring Suggestions"
        
        var prompt: String {
            switch self {
            case .general:
                return "Analyze this code and explain what it does, its strengths, and potential improvements."
            case .performance:
                return "Analyze the performance characteristics of this code. Identify any bottlenecks and suggest optimizations."
            case .security:
                return "Review this code for potential security vulnerabilities and suggest improvements."
            case .refactor:
                return "Suggest how to refactor this code to make it more maintainable, readable, and efficient."
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "doc.text.magnifyingglass"
            case .performance: return "speedometer"
            case .security: return "lock.shield"
            case .refactor: return "arrow.triangle.2.circlepath"
            }
        }
    }
    
    struct CodeAnalysis {
        let code: String
        let type: AnalysisType
        let reasoning: String
        let findings: [Finding]
        let suggestions: [String]
        let improvedCode: String?
        
        struct Finding {
            let title: String
            let description: String
            let severity: Severity
            
            enum Severity {
                case info, warning, error
                
                var color: Color {
                    switch self {
                    case .info: return .blue
                    case .warning: return .orange
                    case .error: return .red
                    }
                }
                
                var icon: String {
                    switch self {
                    case .info: return "info.circle"
                    case .warning: return "exclamationmark.triangle"
                    case .error: return "xmark.circle"
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading) {
                        Text("Code Analysis Tool")
                            .font(.largeTitle)
                            .bold()
                        Text("Powered by DeepSeek Reasoner")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Analysis Type Selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Analysis Type")
                            .font(.headline)
                        
                        Picker("Analysis Type", selection: $selectedAnalysisType) {
                            ForEach(AnalysisType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Code Input
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Code to Analyze", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.headline)
                        
                        TextEditor(text: $codeInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button(action: analyzeCode) {
                        Label("Analyze Code", systemImage: "brain")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(codeInput.isEmpty || isLoading)
                    
                    if isLoading {
                        CodeAnalysisLoadingView()
                    }
                    
                    // Analysis Results
                    if let analysis = analysis {
                        CodeAnalysisResultView(analysis: analysis)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func analyzeCode() {
        isLoading = true
        analysis = nil
        
        Task {
            do {
                let prompt = """
                \(selectedAnalysisType.prompt)
                
                Code:
                ```
                \(codeInput)
                ```
                
                Please provide:
                1. Detailed analysis with reasoning
                2. Specific findings (categorized by severity)
                3. Actionable suggestions
                4. If applicable, improved code
                """
                
                let response = try await client.chat(
                    messages: [.user(prompt)],
                    model: .reasoner
                )
                
                if let choice = response.choices.first {
                    let reasoning = choice.message.reasoningContent ?? ""
                    let content = choice.message.content ?? ""
                    
                    analysis = parseCodeAnalysis(
                        code: codeInput,
                        type: selectedAnalysisType,
                        reasoning: reasoning,
                        content: content
                    )
                }
            } catch {
                // Handle error
                analysis = CodeAnalysis(
                    code: codeInput,
                    type: selectedAnalysisType,
                    reasoning: "",
                    findings: [
                        CodeAnalysis.Finding(
                            title: "Error",
                            description: error.localizedDescription,
                            severity: .error
                        )
                    ],
                    suggestions: [],
                    improvedCode: nil
                )
            }
            
            isLoading = false
        }
    }
    
    private func parseCodeAnalysis(code: String, type: AnalysisType, reasoning: String, content: String) -> CodeAnalysis {
        // Parse findings from content
        var findings: [CodeAnalysis.Finding] = []
        var suggestions: [String] = []
        var improvedCode: String?
        
        // Simple parsing logic (in real app, this would be more sophisticated)
        let lines = content.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                suggestions.append(String(trimmed.dropFirst(2)))
            }
            
            // Look for improved code blocks
            if content.contains("```") {
                let codeBlocks = content.components(separatedBy: "```")
                if codeBlocks.count > 2 {
                    improvedCode = codeBlocks[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Create sample findings based on analysis type
        switch type {
        case .performance:
            findings.append(CodeAnalysis.Finding(
                title: "Exponential Time Complexity",
                description: "The recursive implementation has O(2^n) time complexity",
                severity: .warning
            ))
        case .security:
            findings.append(CodeAnalysis.Finding(
                title: "Stack Overflow Risk",
                description: "Deep recursion could cause stack overflow for large inputs",
                severity: .warning
            ))
        default:
            findings.append(CodeAnalysis.Finding(
                title: "Algorithm Analysis",
                description: "Classic recursive Fibonacci implementation",
                severity: .info
            ))
        }
        
        return CodeAnalysis(
            code: code,
            type: type,
            reasoning: reasoning,
            findings: findings,
            suggestions: suggestions.isEmpty ? ["Consider using memoization", "Add input validation"] : suggestions,
            improvedCode: improvedCode
        )
    }
}

struct CodeAnalysisResultView: View {
    let analysis: ReasonerExample.CodeAnalysis
    @State private var showReasoning = false
    @State private var showImprovedCode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Findings
            VStack(alignment: .leading, spacing: 10) {
                Label("Findings", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                
                ForEach(analysis.findings, id: \.title) { finding in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: finding.severity.icon)
                            .foregroundColor(finding.severity.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(finding.title)
                                .font(.subheadline)
                                .bold()
                            Text(finding.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(finding.severity.color.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Suggestions
            if !analysis.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Suggestions", systemImage: "lightbulb")
                        .font(.headline)
                    
                    ForEach(analysis.suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text(suggestion)
                                .font(.callout)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            // Improved Code
            if analysis.improvedCode != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { showImprovedCode.toggle() }) {
                        Label(
                            showImprovedCode ? "Hide Improved Code" : "Show Improved Code",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(.headline)
                    }
                    
                    if showImprovedCode, let improvedCode = analysis.improvedCode {
                        Text(improvedCode)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Reasoning Toggle
            DisclosureGroup(
                "AI Reasoning Process",
                isExpanded: $showReasoning
            ) {
                Text(analysis.reasoning)
                    .font(.caption)
                    .padding()
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
}

struct CodeAnalysisLoadingView: View {
    @State private var dots = 0
    
    var body: some View {
        HStack {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundColor(.purple)
            
            Text("Analyzing code" + String(repeating: ".", count: dots))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dots = (dots + 1) % 4
            }
        }
    }
}