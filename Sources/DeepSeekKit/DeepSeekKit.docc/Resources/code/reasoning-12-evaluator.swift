import SwiftUI
import DeepSeekKit

// Evaluate reasoning quality
struct ReasoningEvaluatorView: View {
    @StateObject private var evaluator = ReasoningEvaluator()
    @State private var reasoningInput = ""
    @State private var evaluationMode: EvaluationMode = .comprehensive
    @State private var selectedMetrics: Set<QualityMetric> = Set(QualityMetric.allCases)
    
    enum EvaluationMode: String, CaseIterable {
        case comprehensive = "Comprehensive"
        case quick = "Quick Check"
        case detailed = "Detailed Analysis"
        case comparative = "Comparative"
        
        var description: String {
            switch self {
            case .comprehensive: return "Full evaluation of all aspects"
            case .quick: return "Fast basic quality check"
            case .detailed: return "In-depth analysis with examples"
            case .comparative: return "Compare against benchmarks"
            }
        }
        
        var icon: String {
            switch self {
            case .comprehensive: return "square.grid.3x3"
            case .quick: return "bolt"
            case .detailed: return "magnifyingglass"
            case .comparative: return "chart.bar"
            }
        }
    }
    
    enum QualityMetric: String, CaseIterable {
        case logicalCoherence = "Logical Coherence"
        case completeness = "Completeness"
        case accuracy = "Accuracy"
        case clarity = "Clarity"
        case depth = "Depth of Analysis"
        case relevance = "Relevance"
        case efficiency = "Efficiency"
        case creativity = "Creativity"
        
        var icon: String {
            switch self {
            case .logicalCoherence: return "brain"
            case .completeness: return "checkmark.seal"
            case .accuracy: return "target"
            case .clarity: return "eye"
            case .depth: return "arrow.down.to.line"
            case .relevance: return "link"
            case .efficiency: return "speedometer"
            case .creativity: return "lightbulb"
            }
        }
        
        var weight: Double {
            switch self {
            case .logicalCoherence: return 0.20
            case .completeness: return 0.15
            case .accuracy: return 0.20
            case .clarity: return 0.15
            case .depth: return 0.10
            case .relevance: return 0.10
            case .efficiency: return 0.05
            case .creativity: return 0.05
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Input section
                ReasoningInputView(
                    input: $reasoningInput,
                    placeholder: "Paste reasoning content to evaluate..."
                )
                
                // Evaluation settings
                EvaluationSettingsView(
                    mode: $evaluationMode,
                    selectedMetrics: $selectedMetrics
                )
                
                // Evaluate button
                Button(action: performEvaluation) {
                    if evaluator.isEvaluating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Label("Evaluate Reasoning", systemImage: "checkmark.diamond")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(reasoningInput.isEmpty || evaluator.isEvaluating)
                
                // Current evaluation
                if let evaluation = evaluator.currentEvaluation {
                    EvaluationResultsView(
                        evaluation: evaluation,
                        mode: evaluationMode
                    )
                }
                
                // Benchmark comparison
                if evaluationMode == .comparative && !evaluator.benchmarks.isEmpty {
                    BenchmarkComparisonView(
                        currentScore: evaluator.currentEvaluation?.overallScore ?? 0,
                        benchmarks: evaluator.benchmarks
                    )
                }
                
                // Evaluation history
                if !evaluator.evaluationHistory.isEmpty {
                    EvaluationHistoryView(
                        history: evaluator.evaluationHistory,
                        onSelect: { evaluation in
                            evaluator.currentEvaluation = evaluation
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Reasoning Evaluator")
    }
    
    private func performEvaluation() {
        Task {
            await evaluator.evaluateReasoning(
                reasoningInput,
                mode: evaluationMode,
                metrics: Array(selectedMetrics)
            )
        }
    }
}

// MARK: - Reasoning Evaluator Engine

class ReasoningEvaluator: ObservableObject {
    @Published var currentEvaluation: ReasoningEvaluation?
    @Published var evaluationHistory: [ReasoningEvaluation] = []
    @Published var benchmarks: [Benchmark] = []
    @Published var isEvaluating = false
    
    private let client: DeepSeekClient
    
    init() {
        self.client = DeepSeekClient(apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "")
        loadBenchmarks()
    }
    
    func evaluateReasoning(_ reasoning: String, mode: ReasoningEvaluatorView.EvaluationMode, metrics: [ReasoningEvaluatorView.QualityMetric]) async {
        await MainActor.run { isEvaluating = true }
        
        do {
            let messages: [Message] = [
                Message(role: .system, content: """
                    You are an expert at evaluating reasoning quality. Analyze the given reasoning and provide:
                    
                    1. Score each metric on a scale of 0-100
                    2. Identify strengths and weaknesses
                    3. Provide specific examples from the text
                    4. Suggest improvements
                    
                    Metrics to evaluate:
                    \(metrics.map { "- \($0.rawValue)" }.joined(separator: "\n"))
                    
                    Mode: \(mode.rawValue) - \(mode.description)
                    """),
                Message(role: .user, content: "Evaluate this reasoning:\n\n\(reasoning)")
            ]
            
            let params = ChatCompletionParameters(
                model: "deepseek-reasoner",
                messages: messages,
                temperature: 0.1,
                maxTokens: 3000
            )
            
            let response = try await client.chatCompletion(params: params)
            
            if let content = response.choices.first?.message.content {
                let evaluation = parseEvaluation(content, reasoning: reasoning, metrics: metrics)
                
                await MainActor.run {
                    self.currentEvaluation = evaluation
                    self.evaluationHistory.append(evaluation)
                    self.isEvaluating = false
                }
                
                if mode == .comparative {
                    await performBenchmarkComparison(evaluation)
                }
            }
        } catch {
            print("Error evaluating reasoning: \(error)")
            await MainActor.run { isEvaluating = false }
        }
    }
    
    private func parseEvaluation(_ content: String, reasoning: String, metrics: [ReasoningEvaluatorView.QualityMetric]) -> ReasoningEvaluation {
        var scores: [ReasoningEvaluatorView.QualityMetric: Double] = [:]
        var strengths: [String] = []
        var weaknesses: [String] = []
        var suggestions: [String] = []
        var examples: [Example] = []
        
        // Parse scores
        for metric in metrics {
            if let score = extractScore(for: metric.rawValue, from: content) {
                scores[metric] = score
            }
        }
        
        // Parse strengths
        if let strengthsSection = extractSection("Strengths", from: content) {
            strengths = strengthsSection.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.contains("-") }
                .map { $0.replacingOccurrences(of: "- ", with: "") }
        }
        
        // Parse weaknesses
        if let weaknessesSection = extractSection("Weaknesses", from: content) {
            weaknesses = weaknessesSection.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.contains("-") }
                .map { $0.replacingOccurrences(of: "- ", with: "") }
        }
        
        // Parse suggestions
        if let suggestionsSection = extractSection("Suggestions", from: content) {
            suggestions = suggestionsSection.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && ($0.contains("-") || $0.contains("•")) }
                .map { $0.replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "• ", with: "") }
        }
        
        // Parse examples
        examples = extractExamples(from: content)
        
        // Calculate overall score
        let overallScore = calculateOverallScore(scores: scores)
        
        return ReasoningEvaluation(
            id: UUID().uuidString,
            originalReasoning: reasoning,
            scores: scores,
            overallScore: overallScore,
            strengths: strengths,
            weaknesses: weaknesses,
            suggestions: suggestions,
            examples: examples,
            evaluationReasoning: extractReasoning(from: content),
            timestamp: Date()
        )
    }
    
    private func extractScore(for metric: String, from content: String) -> Double? {
        let patterns = [
            "\(metric).*?(\\d+)/100",
            "\(metric).*?Score.*?(\\d+)",
            "\(metric).*?(\\d+)%"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                if let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
                    if let range = Range(match.range(at: 1), in: content) {
                        if let score = Double(content[range]) {
                            return score / 100.0
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractSection(_ section: String, from content: String) -> String? {
        if let sectionRange = content.range(of: "\(section):", options: .caseInsensitive) {
            let startIndex = sectionRange.upperBound
            let remainingContent = String(content[startIndex...])
            
            // Find next section or end of content
            let nextSections = ["Strengths:", "Weaknesses:", "Suggestions:", "Examples:", "Overall:"]
            var endIndex = remainingContent.endIndex
            
            for nextSection in nextSections {
                if let nextRange = remainingContent.range(of: nextSection, options: .caseInsensitive) {
                    endIndex = min(endIndex, nextRange.lowerBound)
                }
            }
            
            return String(remainingContent[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func extractExamples(from content: String) -> [Example] {
        var examples: [Example] = []
        
        if let examplesSection = extractSection("Examples", from: content) {
            let lines = examplesSection.components(separatedBy: "\n")
            var currentExample: (text: String, explanation: String)?
            
            for line in lines {
                if line.contains("Example:") || line.contains("\"") {
                    if let example = currentExample {
                        examples.append(Example(
                            text: example.text,
                            explanation: example.explanation,
                            type: categorizeExample(example.text)
                        ))
                    }
                    currentExample = (text: line, explanation: "")
                } else if let example = currentExample {
                    currentExample?.explanation += " " + line
                }
            }
            
            if let example = currentExample {
                examples.append(Example(
                    text: example.text,
                    explanation: example.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: categorizeExample(example.text)
                ))
            }
        }
        
        return examples
    }
    
    private func categorizeExample(_ text: String) -> ExampleType {
        let lowercased = text.lowercased()
        if lowercased.contains("good") || lowercased.contains("strong") {
            return .strength
        } else if lowercased.contains("weak") || lowercased.contains("poor") {
            return .weakness
        } else {
            return .neutral
        }
    }
    
    private func extractReasoning(from content: String) -> String {
        if content.contains("<Thought>") && content.contains("</Thought>") {
            if let start = content.range(of: "<Thought>"),
               let end = content.range(of: "</Thought>") {
                return String(content[start.upperBound..<end.lowerBound])
            }
        }
        return ""
    }
    
    private func calculateOverallScore(scores: [ReasoningEvaluatorView.QualityMetric: Double]) -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (metric, score) in scores {
            weightedSum += score * metric.weight
            totalWeight += metric.weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0.0
    }
    
    private func performBenchmarkComparison(_ evaluation: ReasoningEvaluation) async {
        // Compare against stored benchmarks
        await MainActor.run {
            // Update benchmark rankings
            for i in benchmarks.indices {
                if evaluation.overallScore > benchmarks[i].score {
                    benchmarks[i].rank += 1
                }
            }
        }
    }
    
    private func loadBenchmarks() {
        // Load sample benchmarks
        benchmarks = [
            Benchmark(name: "Expert Reasoning", score: 0.95, category: "Professional", rank: 1),
            Benchmark(name: "Advanced Student", score: 0.85, category: "Academic", rank: 2),
            Benchmark(name: "Industry Standard", score: 0.80, category: "Professional", rank: 3),
            Benchmark(name: "Intermediate Level", score: 0.70, category: "Academic", rank: 4),
            Benchmark(name: "Baseline", score: 0.60, category: "General", rank: 5)
        ]
    }
}

// MARK: - Data Models

struct ReasoningEvaluation: Identifiable {
    let id: String
    let originalReasoning: String
    let scores: [ReasoningEvaluatorView.QualityMetric: Double]
    let overallScore: Double
    let strengths: [String]
    let weaknesses: [String]
    let suggestions: [String]
    let examples: [Example]
    let evaluationReasoning: String
    let timestamp: Date
}

struct Example: Identifiable {
    let id = UUID()
    let text: String
    let explanation: String
    let type: ExampleType
}

enum ExampleType {
    case strength
    case weakness
    case neutral
    
    var color: Color {
        switch self {
        case .strength: return .green
        case .weakness: return .red
        case .neutral: return .gray
        }
    }
}

struct Benchmark: Identifiable {
    let id = UUID()
    let name: String
    let score: Double
    let category: String
    var rank: Int
}

// MARK: - Supporting Views

struct ReasoningInputView: View {
    @Binding var input: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reasoning Content", systemImage: "doc.text")
                .font(.headline)
            
            TextEditor(text: $input)
                .frame(height: 150)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    Group {
                        if input.isEmpty {
                            Text(placeholder)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
            
            HStack {
                Text("\(input.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Load Sample") {
                    input = """
                    To solve this mathematical problem, I'll use the quadratic formula.
                    
                    First, I identify the coefficients: a = 2, b = -5, c = 3
                    
                    Next, I apply the quadratic formula: x = (-b ± √(b² - 4ac)) / 2a
                    
                    Calculating the discriminant: b² - 4ac = 25 - 24 = 1
                    
                    Since the discriminant is positive, we have two real solutions:
                    x₁ = (5 + 1) / 4 = 1.5
                    x₂ = (5 - 1) / 4 = 1
                    
                    Therefore, the solutions are x = 1.5 and x = 1.
                    """
                }
                .font(.caption)
            }
        }
    }
}

struct EvaluationSettingsView: View {
    @Binding var mode: ReasoningEvaluatorView.EvaluationMode
    @Binding var selectedMetrics: Set<ReasoningEvaluatorView.QualityMetric>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mode selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Evaluation Mode")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ReasoningEvaluatorView.EvaluationMode.allCases, id: \.self) { mode in
                            ModeCard(
                                mode: mode,
                                isSelected: self.mode == mode,
                                action: { self.mode = mode }
                            )
                        }
                    }
                }
            }
            
            // Metrics selector
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quality Metrics")
                        .font(.headline)
                    Spacer()
                    Button(selectedMetrics.count == ReasoningEvaluatorView.QualityMetric.allCases.count ? "Deselect All" : "Select All") {
                        if selectedMetrics.count == ReasoningEvaluatorView.QualityMetric.allCases.count {
                            selectedMetrics.removeAll()
                        } else {
                            selectedMetrics = Set(ReasoningEvaluatorView.QualityMetric.allCases)
                        }
                    }
                    .font(.caption)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                    ForEach(ReasoningEvaluatorView.QualityMetric.allCases, id: \.self) { metric in
                        MetricToggle(
                            metric: metric,
                            isSelected: selectedMetrics.contains(metric),
                            action: {
                                if selectedMetrics.contains(metric) {
                                    selectedMetrics.remove(metric)
                                } else {
                                    selectedMetrics.insert(metric)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ModeCard: View {
    let mode: ReasoningEvaluatorView.EvaluationMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)
                Text(mode.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 100, height: 80)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MetricToggle: View {
    let metric: ReasoningEvaluatorView.QualityMetric
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: metric.icon)
                    .foregroundColor(isSelected ? .blue : .gray)
                Text(metric.rawValue)
                    .font(.caption)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EvaluationResultsView: View {
    let evaluation: ReasoningEvaluation
    let mode: ReasoningEvaluatorView.EvaluationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall score
            OverallScoreView(score: evaluation.overallScore)
            
            // Individual scores
            if mode == .detailed || mode == .comprehensive {
                MetricScoresView(scores: evaluation.scores)
            }
            
            // Strengths and weaknesses
            if !evaluation.strengths.isEmpty || !evaluation.weaknesses.isEmpty {
                StrengthsWeaknessesView(
                    strengths: evaluation.strengths,
                    weaknesses: evaluation.weaknesses
                )
            }
            
            // Examples
            if mode == .detailed && !evaluation.examples.isEmpty {
                ExamplesView(examples: evaluation.examples)
            }
            
            // Suggestions
            if !evaluation.suggestions.isEmpty {
                SuggestionsView(suggestions: evaluation.suggestions)
            }
        }
    }
}

struct OverallScoreView: View {
    let score: Double
    
    var scoreColor: Color {
        if score >= 0.9 { return .green }
        else if score >= 0.7 { return .blue }
        else if score >= 0.5 { return .orange }
        else { return .red }
    }
    
    var scoreLabel: String {
        if score >= 0.9 { return "Excellent" }
        else if score >= 0.7 { return "Good" }
        else if score >= 0.5 { return "Fair" }
        else { return "Needs Improvement" }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Overall Score")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: score)
                
                VStack {
                    Text("\(Int(score * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(scoreLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, height: 150)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MetricScoresView: View {
    let scores: [ReasoningEvaluatorView.QualityMetric: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detailed Scores")
                .font(.headline)
            
            ForEach(Array(scores.sorted(by: { $0.value > $1.value })), id: \.key) { metric, score in
                HStack {
                    Label(metric.rawValue, systemImage: metric.icon)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(score * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: score)
                    .progressViewStyle(LinearProgressViewStyle(tint: colorForScore(score)))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        else if score >= 0.6 { return .blue }
        else if score >= 0.4 { return .orange }
        else { return .red }
    }
}

struct StrengthsWeaknessesView: View {
    let strengths: [String]
    let weaknesses: [String]
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Strengths
            VStack(alignment: .leading, spacing: 8) {
                Label("Strengths", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                
                ForEach(strengths, id: \.self) { strength in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(strength)
                            .font(.subheadline)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            // Weaknesses
            VStack(alignment: .leading, spacing: 8) {
                Label("Areas for Improvement", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                ForEach(weaknesses, id: \.self) { weakness in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(weakness)
                            .font(.subheadline)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct ExamplesView: View {
    let examples: [Example]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Examples from Text")
                .font(.headline)
            
            ForEach(examples) { example in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(example.type.color)
                            .frame(width: 8, height: 8)
                        Text(example.text)
                            .font(.caption)
                            .italic()
                    }
                    
                    Text(example.explanation)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                }
                .padding()
                .background(example.type.color.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

struct SuggestionsView: View {
    let suggestions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Improvement Suggestions", systemImage: "lightbulb")
                .font(.headline)
                .foregroundColor(.blue)
            
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text(suggestion)
                        .font(.subheadline)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

struct BenchmarkComparisonView: View {
    let currentScore: Double
    let benchmarks: [Benchmark]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Benchmark Comparison")
                .font(.headline)
            
            ForEach(benchmarks.sorted(by: { $0.score > $1.score })) { benchmark in
                HStack {
                    VStack(alignment: .leading) {
                        Text(benchmark.name)
                            .font(.subheadline)
                        Text(benchmark.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(benchmark.score * 100))%")
                        .font(.caption)
                        .fontWeight(currentScore > benchmark.score ? .bold : .regular)
                        .foregroundColor(currentScore > benchmark.score ? .green : .secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * benchmark.score, height: 8)
                            .cornerRadius(4)
                        
                        if currentScore > 0 {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width * currentScore, height: 4)
                                .cornerRadius(2)
                                .offset(y: 2)
                        }
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct EvaluationHistoryView: View {
    let history: [ReasoningEvaluation]
    let onSelect: (ReasoningEvaluation) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evaluation History")
                .font(.headline)
            
            ForEach(history.reversed()) { evaluation in
                Button(action: { onSelect(evaluation) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(evaluation.originalReasoning)
                                .lineLimit(2)
                                .font(.subheadline)
                            Text(evaluation.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        CircularScoreView(score: evaluation.overallScore)
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

struct CircularScoreView: View {
    let score: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                .frame(width: 40, height: 40)
            
            Circle()
                .trim(from: 0, to: score)
                .stroke(colorForScore(score), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(score * 100))")
                .font(.caption)
                .fontWeight(.bold)
        }
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        else if score >= 0.6 { return .blue }
        else if score >= 0.4 { return .orange }
        else { return .red }
    }
}

// MARK: - App

struct ReasoningEvaluatorApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ReasoningEvaluatorView()
            }
        }
    }
}