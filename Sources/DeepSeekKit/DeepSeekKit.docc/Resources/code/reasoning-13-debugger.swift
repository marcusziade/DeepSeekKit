import SwiftUI
import DeepSeekKit

// Debug and improve reasoning
struct ReasoningDebuggerView: View {
    @StateObject private var debugger = ReasoningDebugger()
    @State private var reasoningInput = ""
    @State private var problemDescription = ""
    @State private var debugMode: DebugMode = .stepByStep
    @State private var showingDebugConsole = false
    
    enum DebugMode: String, CaseIterable {
        case stepByStep = "Step-by-Step"
        case logical = "Logical Flow"
        case assumptions = "Assumptions"
        case evidence = "Evidence Check"
        case errors = "Error Detection"
        
        var icon: String {
            switch self {
            case .stepByStep: return "list.number"
            case .logical: return "arrow.triangle.branch"
            case .assumptions: return "questionmark.circle"
            case .evidence: return "doc.text.magnifyingglass"
            case .errors: return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .stepByStep: return .blue
            case .logical: return .purple
            case .assumptions: return .orange
            case .evidence: return .green
            case .errors: return .red
            }
        }
        
        var description: String {
            switch self {
            case .stepByStep: return "Trace through reasoning steps"
            case .logical: return "Analyze logical connections"
            case .assumptions: return "Identify hidden assumptions"
            case .evidence: return "Verify supporting evidence"
            case .errors: return "Find reasoning errors"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Input section
                DebugInputSection(
                    reasoning: $reasoningInput,
                    problem: $problemDescription
                )
                
                // Debug mode selector
                DebugModeSelector(
                    selectedMode: $debugMode,
                    onModeChange: { debugger.currentMode = $0 }
                )
                
                // Debug controls
                DebugControlsView(
                    onDebug: startDebugging,
                    onStep: stepThrough,
                    onReset: resetDebugger,
                    isDebugging: debugger.isDebugging,
                    canStep: debugger.canStep
                )
                
                // Current debug state
                if let debugState = debugger.currentDebugState {
                    DebugStateView(state: debugState)
                }
                
                // Issues found
                if !debugger.issuesFound.isEmpty {
                    IssuesFoundView(issues: debugger.issuesFound)
                }
                
                // Improvements
                if let improvedReasoning = debugger.improvedReasoning {
                    ImprovedReasoningView(
                        original: reasoningInput,
                        improved: improvedReasoning,
                        improvements: debugger.improvements
                    )
                }
                
                // Debug history
                if !debugger.debugHistory.isEmpty {
                    DebugHistoryView(
                        history: debugger.debugHistory,
                        onSelect: { session in
                            loadDebugSession(session)
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Reasoning Debugger")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingDebugConsole.toggle() }) {
                    Image(systemName: "terminal")
                }
            }
        }
        .sheet(isPresented: $showingDebugConsole) {
            DebugConsoleView(debugger: debugger)
        }
    }
    
    private func startDebugging() {
        Task {
            await debugger.startDebugging(
                reasoning: reasoningInput,
                problem: problemDescription,
                mode: debugMode
            )
        }
    }
    
    private func stepThrough() {
        Task {
            await debugger.stepThrough()
        }
    }
    
    private func resetDebugger() {
        debugger.reset()
    }
    
    private func loadDebugSession(_ session: DebugSession) {
        reasoningInput = session.originalReasoning
        problemDescription = session.problem
        debugger.loadSession(session)
    }
}

// MARK: - Reasoning Debugger Engine

class ReasoningDebugger: ObservableObject {
    @Published var currentDebugState: DebugState?
    @Published var issuesFound: [ReasoningIssue] = []
    @Published var improvedReasoning: String?
    @Published var improvements: [Improvement] = []
    @Published var debugHistory: [DebugSession] = []
    @Published var isDebugging = false
    @Published var canStep = false
    @Published var currentMode: ReasoningDebuggerView.DebugMode = .stepByStep
    
    private var debugSteps: [DebugStep] = []
    private var currentStepIndex = 0
    private let client: DeepSeekClient
    
    init() {
        self.client = DeepSeekClient(apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "")
    }
    
    func startDebugging(reasoning: String, problem: String, mode: ReasoningDebuggerView.DebugMode) async {
        await MainActor.run {
            isDebugging = true
            issuesFound.removeAll()
            improvements.removeAll()
            improvedReasoning = nil
        }
        
        do {
            let messages: [Message] = [
                Message(role: .system, content: """
                    You are a reasoning debugger that helps identify and fix issues in logical reasoning.
                    
                    Debug Mode: \(mode.rawValue)
                    Task: \(mode.description)
                    
                    Analyze the given reasoning for:
                    1. Logical errors and fallacies
                    2. Missing steps or assumptions
                    3. Incorrect conclusions
                    4. Weak evidence or support
                    5. Circular reasoning
                    
                    Provide step-by-step analysis and suggest improvements.
                    """),
                Message(role: .user, content: """
                    Problem: \(problem)
                    
                    Reasoning to debug:
                    \(reasoning)
                    """)
            ]
            
            let params = ChatCompletionParameters(
                model: "deepseek-reasoner",
                messages: messages,
                temperature: 0.1,
                maxTokens: 4000
            )
            
            let response = try await client.chatCompletion(params: params)
            
            if let content = response.choices.first?.message.content {
                let analysis = parseDebugAnalysis(content, originalReasoning: reasoning)
                
                await MainActor.run {
                    self.debugSteps = analysis.steps
                    self.issuesFound = analysis.issues
                    self.improvements = analysis.improvements
                    self.improvedReasoning = analysis.improvedReasoning
                    
                    if !debugSteps.isEmpty {
                        self.currentStepIndex = 0
                        self.currentDebugState = createDebugState(for: debugSteps[0])
                        self.canStep = debugSteps.count > 1
                    }
                    
                    // Save to history
                    let session = DebugSession(
                        id: UUID().uuidString,
                        originalReasoning: reasoning,
                        problem: problem,
                        mode: mode,
                        issues: analysis.issues,
                        improvements: analysis.improvements,
                        improvedReasoning: analysis.improvedReasoning,
                        timestamp: Date()
                    )
                    self.debugHistory.append(session)
                    
                    self.isDebugging = false
                }
            }
        } catch {
            print("Error debugging reasoning: \(error)")
            await MainActor.run { isDebugging = false }
        }
    }
    
    func stepThrough() async {
        guard currentStepIndex < debugSteps.count - 1 else { return }
        
        await MainActor.run {
            currentStepIndex += 1
            currentDebugState = createDebugState(for: debugSteps[currentStepIndex])
            canStep = currentStepIndex < debugSteps.count - 1
        }
    }
    
    func reset() {
        currentDebugState = nil
        issuesFound.removeAll()
        improvedReasoning = nil
        improvements.removeAll()
        debugSteps.removeAll()
        currentStepIndex = 0
        canStep = false
    }
    
    func loadSession(_ session: DebugSession) {
        currentDebugState = nil
        issuesFound = session.issues
        improvements = session.improvements
        improvedReasoning = session.improvedReasoning
        currentMode = session.mode
    }
    
    private func parseDebugAnalysis(_ content: String, originalReasoning: String) -> DebugAnalysis {
        var steps: [DebugStep] = []
        var issues: [ReasoningIssue] = []
        var improvements: [Improvement] = []
        var improvedReasoning = ""
        
        // Parse debug steps
        steps = extractDebugSteps(from: content)
        
        // Parse issues
        issues = extractIssues(from: content)
        
        // Parse improvements
        improvements = extractImprovements(from: content)
        
        // Parse improved reasoning
        if let improvedSection = extractSection("Improved Reasoning", from: content) {
            improvedReasoning = improvedSection
        }
        
        return DebugAnalysis(
            steps: steps,
            issues: issues,
            improvements: improvements,
            improvedReasoning: improvedReasoning.isEmpty ? nil : improvedReasoning
        )
    }
    
    private func extractDebugSteps(from content: String) -> [DebugStep] {
        var steps: [DebugStep] = []
        
        let stepPattern = #"Step (\d+):(.+?)(?=Step \d+:|Issues:|$)"#
        if let regex = try? NSRegularExpression(pattern: stepPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                if let numberRange = Range(match.range(at: 1), in: content),
                   let contentRange = Range(match.range(at: 2), in: content) {
                    let stepNumber = Int(content[numberRange]) ?? 0
                    let stepContent = String(content[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let step = DebugStep(
                        number: stepNumber,
                        content: extractStepContent(from: stepContent),
                        analysis: extractStepAnalysis(from: stepContent),
                        issues: extractStepIssues(from: stepContent),
                        status: determineStepStatus(from: stepContent)
                    )
                    steps.append(step)
                }
            }
        }
        
        return steps
    }
    
    private func extractStepContent(from text: String) -> String {
        if let contentRange = text.range(of: "Content:") {
            let content = String(text[contentRange.upperBound...])
            if let analysisRange = content.range(of: "Analysis:") {
                return String(content[..<analysisRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.components(separatedBy: "\n").first ?? text
    }
    
    private func extractStepAnalysis(from text: String) -> String {
        if let analysisRange = text.range(of: "Analysis:") {
            let analysis = String(text[analysisRange.upperBound...])
            if let issuesRange = analysis.range(of: "Issues:") {
                return String(analysis[..<issuesRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return analysis.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    
    private func extractStepIssues(from text: String) -> [String] {
        if let issuesRange = text.range(of: "Issues:") {
            let issuesText = String(text[issuesRange.upperBound...])
            return issuesText.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && ($0.contains("-") || $0.contains("•")) }
                .map { $0.replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "• ", with: "") }
        }
        return []
    }
    
    private func determineStepStatus(from text: String) -> StepStatus {
        let lowercased = text.lowercased()
        if lowercased.contains("error") || lowercased.contains("incorrect") || lowercased.contains("wrong") {
            return .error
        } else if lowercased.contains("warning") || lowercased.contains("issue") || lowercased.contains("problem") {
            return .warning
        } else {
            return .valid
        }
    }
    
    private func extractIssues(from content: String) -> [ReasoningIssue] {
        var issues: [ReasoningIssue] = []
        
        if let issuesSection = extractSection("Issues Found", from: content) {
            let issueLines = issuesSection.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for (index, line) in issueLines.enumerated() {
                let severity = determineSeverity(from: line)
                let category = categorizeIssue(from: line)
                
                let issue = ReasoningIssue(
                    id: "\(index)",
                    description: line.replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "• ", with: ""),
                    severity: severity,
                    category: category,
                    location: extractLocation(from: line),
                    suggestion: extractSuggestion(from: line)
                )
                issues.append(issue)
            }
        }
        
        return issues
    }
    
    private func determineSeverity(from text: String) -> IssueSeverity {
        let lowercased = text.lowercased()
        if lowercased.contains("critical") || lowercased.contains("fatal") {
            return .critical
        } else if lowercased.contains("error") || lowercased.contains("major") {
            return .error
        } else if lowercased.contains("warning") || lowercased.contains("minor") {
            return .warning
        } else {
            return .info
        }
    }
    
    private func categorizeIssue(from text: String) -> IssueCategory {
        let lowercased = text.lowercased()
        if lowercased.contains("logic") || lowercased.contains("fallacy") {
            return .logical
        } else if lowercased.contains("assumption") {
            return .assumption
        } else if lowercased.contains("evidence") || lowercased.contains("support") {
            return .evidence
        } else if lowercased.contains("conclusion") {
            return .conclusion
        } else {
            return .other
        }
    }
    
    private func extractLocation(from text: String) -> String? {
        if let stepMatch = text.range(of: "Step \\d+", options: .regularExpression) {
            return String(text[stepMatch])
        }
        return nil
    }
    
    private func extractSuggestion(from text: String) -> String? {
        if let suggestionRange = text.range(of: "Suggestion:") {
            return String(text[suggestionRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func extractImprovements(from content: String) -> [Improvement] {
        var improvements: [Improvement] = []
        
        if let improvementsSection = extractSection("Improvements", from: content) {
            let improvementBlocks = improvementsSection.components(separatedBy: "\n\n")
            
            for block in improvementBlocks {
                if !block.isEmpty {
                    let improvement = Improvement(
                        original: extractOriginal(from: block),
                        improved: extractImproved(from: block),
                        explanation: extractExplanation(from: block),
                        impact: determineImpact(from: block)
                    )
                    improvements.append(improvement)
                }
            }
        }
        
        return improvements
    }
    
    private func extractOriginal(from block: String) -> String {
        if let originalRange = block.range(of: "Original:") {
            let original = String(block[originalRange.upperBound...])
            if let improvedRange = original.range(of: "Improved:") {
                return String(original[..<improvedRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }
    
    private func extractImproved(from block: String) -> String {
        if let improvedRange = block.range(of: "Improved:") {
            let improved = String(block[improvedRange.upperBound...])
            if let explanationRange = improved.range(of: "Explanation:") {
                return String(improved[..<explanationRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }
    
    private func extractExplanation(from block: String) -> String {
        if let explanationRange = block.range(of: "Explanation:") {
            return String(block[explanationRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    
    private func determineImpact(from block: String) -> ImpactLevel {
        let lowercased = block.lowercased()
        if lowercased.contains("high impact") || lowercased.contains("significant") {
            return .high
        } else if lowercased.contains("medium impact") || lowercased.contains("moderate") {
            return .medium
        } else {
            return .low
        }
    }
    
    private func extractSection(_ section: String, from content: String) -> String? {
        if let sectionRange = content.range(of: "\(section):", options: .caseInsensitive) {
            let startIndex = sectionRange.upperBound
            let remainingContent = String(content[startIndex...])
            
            // Find next section
            let sections = ["Step", "Issues", "Improvements", "Improved Reasoning"]
            var endIndex = remainingContent.endIndex
            
            for nextSection in sections {
                if let nextRange = remainingContent.range(of: "\(nextSection):", options: .caseInsensitive) {
                    endIndex = min(endIndex, nextRange.lowerBound)
                }
            }
            
            return String(remainingContent[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func createDebugState(for step: DebugStep) -> DebugState {
        return DebugState(
            currentStep: step,
            totalSteps: debugSteps.count,
            currentIndex: currentStepIndex,
            variables: extractVariables(from: step),
            assumptions: extractAssumptions(from: step),
            conclusions: extractConclusions(from: step)
        )
    }
    
    private func extractVariables(from step: DebugStep) -> [String: String] {
        // Extract any variables or values mentioned in the step
        var variables: [String: String] = [:]
        
        let pattern = #"(\w+)\s*=\s*([^,\n]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: step.content, range: NSRange(step.content.startIndex..., in: step.content))
            
            for match in matches {
                if let varRange = Range(match.range(at: 1), in: step.content),
                   let valueRange = Range(match.range(at: 2), in: step.content) {
                    let variable = String(step.content[varRange])
                    let value = String(step.content[valueRange])
                    variables[variable] = value
                }
            }
        }
        
        return variables
    }
    
    private func extractAssumptions(from step: DebugStep) -> [String] {
        // Extract assumptions from the analysis
        var assumptions: [String] = []
        
        if step.analysis.lowercased().contains("assum") {
            let lines = step.analysis.components(separatedBy: "\n")
            for line in lines {
                if line.lowercased().contains("assum") {
                    assumptions.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        return assumptions
    }
    
    private func extractConclusions(from step: DebugStep) -> [String] {
        // Extract conclusions from the step
        var conclusions: [String] = []
        
        let keywords = ["therefore", "thus", "hence", "conclude", "result"]
        let lines = step.content.components(separatedBy: "\n")
        
        for line in lines {
            let lowercased = line.lowercased()
            if keywords.contains(where: lowercased.contains) {
                conclusions.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        return conclusions
    }
}

// MARK: - Data Models

struct DebugAnalysis {
    let steps: [DebugStep]
    let issues: [ReasoningIssue]
    let improvements: [Improvement]
    let improvedReasoning: String?
}

struct DebugStep {
    let number: Int
    let content: String
    let analysis: String
    let issues: [String]
    let status: StepStatus
}

enum StepStatus {
    case valid
    case warning
    case error
    
    var color: Color {
        switch self {
        case .valid: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .valid: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

struct DebugState {
    let currentStep: DebugStep
    let totalSteps: Int
    let currentIndex: Int
    let variables: [String: String]
    let assumptions: [String]
    let conclusions: [String]
}

struct ReasoningIssue: Identifiable {
    let id: String
    let description: String
    let severity: IssueSeverity
    let category: IssueCategory
    let location: String?
    let suggestion: String?
}

enum IssueSeverity {
    case critical
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .error: return .orange
        case .warning: return .yellow
        case .info: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .critical: return "xmark.octagon.fill"
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

enum IssueCategory {
    case logical
    case assumption
    case evidence
    case conclusion
    case other
    
    var label: String {
        switch self {
        case .logical: return "Logic"
        case .assumption: return "Assumption"
        case .evidence: return "Evidence"
        case .conclusion: return "Conclusion"
        case .other: return "Other"
        }
    }
}

struct Improvement: Identifiable {
    let id = UUID()
    let original: String
    let improved: String
    let explanation: String
    let impact: ImpactLevel
}

enum ImpactLevel {
    case high
    case medium
    case low
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

struct DebugSession: Identifiable {
    let id: String
    let originalReasoning: String
    let problem: String
    let mode: ReasoningDebuggerView.DebugMode
    let issues: [ReasoningIssue]
    let improvements: [Improvement]
    let improvedReasoning: String?
    let timestamp: Date
}

// MARK: - Supporting Views

struct DebugInputSection: View {
    @Binding var reasoning: String
    @Binding var problem: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Problem description
            VStack(alignment: .leading, spacing: 4) {
                Label("Problem Description", systemImage: "questionmark.circle")
                    .font(.headline)
                
                TextField("What problem is the reasoning trying to solve?", text: $problem)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Reasoning input
            VStack(alignment: .leading, spacing: 4) {
                Label("Reasoning to Debug", systemImage: "doc.text")
                    .font(.headline)
                
                TextEditor(text: $reasoning)
                    .frame(height: 150)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                HStack {
                    Text("\(reasoning.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Load Example") {
                        problem = "Find the maximum value in an array"
                        reasoning = """
                        To find the maximum value in an array:
                        1. Set max = first element
                        2. Loop through array starting from index 0
                        3. If current element > max, update max
                        4. Return max
                        
                        This works because we compare every element.
                        """
                    }
                    .font(.caption)
                }
            }
        }
    }
}

struct DebugModeSelector: View {
    @Binding var selectedMode: ReasoningDebuggerView.DebugMode
    let onModeChange: (ReasoningDebuggerView.DebugMode) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Mode")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ReasoningDebuggerView.DebugMode.allCases, id: \.self) { mode in
                        DebugModeCard(
                            mode: mode,
                            isSelected: selectedMode == mode,
                            action: {
                                selectedMode = mode
                                onModeChange(mode)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct DebugModeCard: View {
    let mode: ReasoningDebuggerView.DebugMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : mode.color)
                
                Text(mode.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(mode.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
            }
            .padding()
            .background(isSelected ? mode.color : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DebugControlsView: View {
    let onDebug: () -> Void
    let onStep: () -> Void
    let onReset: () -> Void
    let isDebugging: Bool
    let canStep: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onDebug) {
                if isDebugging {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Label("Debug", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDebugging)
            
            Button(action: onStep) {
                Label("Step", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!canStep || isDebugging)
            
            Button(action: onReset) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isDebugging)
        }
    }
}

struct DebugStateView: View {
    let state: DebugState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Progress
            HStack {
                Text("Step \(state.currentIndex + 1) of \(state.totalSteps)")
                    .font(.headline)
                
                Spacer()
                
                Label(state.currentStep.status == .valid ? "Valid" : state.currentStep.status == .warning ? "Warning" : "Error",
                      systemImage: state.currentStep.status.icon)
                    .foregroundColor(state.currentStep.status.color)
                    .font(.caption)
            }
            
            // Current step content
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Step")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(state.currentStep.content)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // Analysis
            if !state.currentStep.analysis.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analysis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(state.currentStep.analysis)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                }
            }
            
            // Step issues
            if !state.currentStep.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Issues in this step")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    ForEach(state.currentStep.issues, id: \.self) { issue in
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(issue)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Variables
            if !state.variables.isEmpty {
                VariablesView(variables: state.variables)
            }
            
            // Assumptions
            if !state.assumptions.isEmpty {
                AssumptionsView(assumptions: state.assumptions)
            }
            
            // Conclusions
            if !state.conclusions.isEmpty {
                ConclusionsView(conclusions: state.conclusions)
            }
        }
        .padding()
        .background(state.currentStep.status.color.opacity(0.05))
        .cornerRadius(12)
    }
}

struct VariablesView: View {
    let variables: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Variables", systemImage: "equal.circle")
                .font(.caption)
                .fontWeight(.medium)
            
            ForEach(Array(variables.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                    Text("=")
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

struct AssumptionsView: View {
    let assumptions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Assumptions", systemImage: "questionmark.circle")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            
            ForEach(assumptions, id: \.self) { assumption in
                HStack(alignment: .top) {
                    Text("•")
                    Text(assumption)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ConclusionsView: View {
    let conclusions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Conclusions", systemImage: "arrow.down.to.line")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
            
            ForEach(conclusions, id: \.self) { conclusion in
                HStack(alignment: .top) {
                    Text("→")
                    Text(conclusion)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }
}

struct IssuesFoundView: View {
    let issues: [ReasoningIssue]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Issues Found (\(issues.count))", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.orange)
            
            ForEach(issues) { issue in
                IssueCard(issue: issue)
            }
        }
    }
}

struct IssueCard: View {
    let issue: ReasoningIssue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(issue.severity == .critical ? "Critical" : 
                      issue.severity == .error ? "Error" : 
                      issue.severity == .warning ? "Warning" : "Info",
                      systemImage: issue.severity.icon)
                    .font(.caption)
                    .foregroundColor(issue.severity.color)
                
                Text(issue.category.label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                if let location = issue.location {
                    Text(location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(issue.description)
                .font(.subheadline)
            
            if let suggestion = issue.suggestion {
                Label(suggestion, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(issue.severity.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ImprovedReasoningView: View {
    let original: String
    let improved: String
    let improvements: [Improvement]
    @State private var showingComparison = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Improved Reasoning", systemImage: "checkmark.seal")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("Compare") {
                    showingComparison = true
                }
                .font(.caption)
            }
            
            // Improvements list
            if !improvements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Improvements")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(improvements) { improvement in
                        ImprovementCard(improvement: improvement)
                    }
                }
            }
            
            // Improved text
            ScrollView {
                Text(improved)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingComparison) {
            ComparisonView(original: original, improved: improved)
        }
    }
}

struct ImprovementCard: View {
    let improvement: Improvement
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Circle()
                        .fill(improvement.impact.color)
                        .frame(width: 8, height: 8)
                    
                    Text(improvement.explanation)
                        .font(.caption)
                        .lineLimit(isExpanded ? nil : 1)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original:")
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text(improvement.original)
                        .font(.caption2)
                        .padding(4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("Improved:")
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text(improvement.improved)
                        .font(.caption2)
                        .padding(4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.leading, 16)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

struct ComparisonView: View {
    let original: String
    let improved: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Original
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Original Reasoning", systemImage: "doc.text")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(original)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                    }
                    
                    // Improved
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Improved Reasoning", systemImage: "doc.text.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text(improved)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Reasoning Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DebugHistoryView: View {
    let history: [DebugSession]
    let onSelect: (DebugSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug History")
                .font(.headline)
            
            ForEach(history.reversed()) { session in
                Button(action: { onSelect(session) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: session.mode.icon)
                                .foregroundColor(session.mode.color)
                            
                            Text(session.problem)
                                .lineLimit(1)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("\(session.issues.count) issues")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(session.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if session.improvedReasoning != nil {
                            Label("Improved version available", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct DebugConsoleView: View {
    @ObservedObject var debugger: ReasoningDebugger
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Current state
                    if let state = debugger.currentDebugState {
                        ConsoleSection(title: "Current State") {
                            Text("Step: \(state.currentIndex + 1)/\(state.totalSteps)")
                            Text("Status: \(state.currentStep.status == .valid ? "Valid" : state.currentStep.status == .warning ? "Warning" : "Error")")
                        }
                    }
                    
                    // Issues
                    if !debugger.issuesFound.isEmpty {
                        ConsoleSection(title: "Issues (\(debugger.issuesFound.count))") {
                            ForEach(debugger.issuesFound) { issue in
                                HStack {
                                    Image(systemName: issue.severity.icon)
                                        .foregroundColor(issue.severity.color)
                                    Text("[\(issue.category.label)] \(issue.description)")
                                        .font(.system(.caption, design: .monospaced))
                                }
                            }
                        }
                    }
                    
                    // Improvements
                    if !debugger.improvements.isEmpty {
                        ConsoleSection(title: "Improvements (\(debugger.improvements.count))") {
                            ForEach(debugger.improvements) { improvement in
                                Text(improvement.explanation)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ConsoleSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("--- \(title) ---")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
            
            content()
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(4)
    }
}

// MARK: - App

struct ReasoningDebuggerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ReasoningDebuggerView()
            }
        }
    }
}