import SwiftUI
import DeepSeekKit

// Compare reasoning approaches
struct ReasoningComparisonView: View {
    @StateObject private var comparator = ReasoningComparator()
    @State private var problem = ""
    @State private var comparisonMode: ComparisonMode = .quality
    @State private var selectedApproaches: Set<ReasoningApproach> = [.stepByStep, .analytical]
    
    enum ComparisonMode: String, CaseIterable {
        case quality = "Quality"
        case performance = "Performance"
        case cost = "Cost Analysis"
        case comprehensive = "Comprehensive"
        
        var metrics: [MetricType] {
            switch self {
            case .quality:
                return [.accuracy, .clarity, .completeness]
            case .performance:
                return [.speed, .tokenUsage, .efficiency]
            case .cost:
                return [.tokenCost, .timeValue, .roi]
            case .comprehensive:
                return MetricType.allCases
            }
        }
    }
    
    enum MetricType: String, CaseIterable {
        case accuracy = "Accuracy"
        case clarity = "Clarity"
        case completeness = "Completeness"
        case speed = "Speed"
        case tokenUsage = "Token Usage"
        case efficiency = "Efficiency"
        case tokenCost = "Token Cost"
        case timeValue = "Time Value"
        case roi = "ROI"
        
        var icon: String {
            switch self {
            case .accuracy: return "target"
            case .clarity: return "eye"
            case .completeness: return "checkmark.seal"
            case .speed: return "speedometer"
            case .tokenUsage: return "doc.text"
            case .efficiency: return "bolt"
            case .tokenCost: return "dollarsign.circle"
            case .timeValue: return "clock.arrow.circlepath"
            case .roi: return "chart.line.uptrend.xyaxis"
            }
        }
        
        var unit: String {
            switch self {
            case .accuracy, .clarity, .completeness, .efficiency, .roi:
                return "%"
            case .speed:
                return "s"
            case .tokenUsage:
                return "tokens"
            case .tokenCost:
                return "$"
            case .timeValue:
                return "$/hr"
            }
        }
    }
    
    enum ReasoningApproach: String, CaseIterable {
        case stepByStep = "Step-by-Step"
        case analytical = "Analytical"
        case intuitive = "Intuitive"
        case systematic = "Systematic"
        case creative = "Creative"
        
        var description: String {
            switch self {
            case .stepByStep:
                return "Break down into sequential steps"
            case .analytical:
                return "Deep analysis of components"
            case .intuitive:
                return "Pattern recognition and insights"
            case .systematic:
                return "Structured methodology"
            case .creative:
                return "Novel approaches and solutions"
            }
        }
        
        var color: Color {
            switch self {
            case .stepByStep: return .blue
            case .analytical: return .purple
            case .intuitive: return .green
            case .systematic: return .orange
            case .creative: return .pink
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Problem input
                ProblemInputSection(
                    problem: $problem,
                    onLoadExample: loadExampleProblem
                )
                
                // Approach selector
                ApproachSelector(
                    selectedApproaches: $selectedApproaches
                )
                
                // Comparison mode
                ComparisonModeSelector(
                    selectedMode: $comparisonMode
                )
                
                // Compare button
                Button(action: performComparison) {
                    if comparator.isComparing {
                        HStack {
                            ProgressView()
                            Text("Comparing...")
                        }
                    } else {
                        Label("Compare Approaches", systemImage: "arrow.triangle.swap")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(problem.isEmpty || selectedApproaches.count < 2 || comparator.isComparing)
                
                // Results
                if let results = comparator.comparisonResults {
                    ComparisonResultsView(
                        results: results,
                        mode: comparisonMode
                    )
                }
                
                // Insights
                if !comparator.insights.isEmpty {
                    InsightsSection(insights: comparator.insights)
                }
            }
            .padding()
        }
        .navigationTitle("Reasoning Comparison")
    }
    
    private func performComparison() {
        Task {
            await comparator.compare(
                problem: problem,
                approaches: Array(selectedApproaches),
                mode: comparisonMode
            )
        }
    }
    
    private func loadExampleProblem() {
        problem = """
        A company needs to reduce operational costs by 20% while maintaining service quality. 
        They have 100 employees, monthly costs of $500,000, and serve 10,000 customers. 
        What strategies should they consider?
        """
    }
}

// MARK: - Reasoning Comparator

class ReasoningComparator: ObservableObject {
    @Published var comparisonResults: ComparisonResults?
    @Published var insights: [Insight] = []
    @Published var isComparing = false
    
    private let client: DeepSeekClient
    
    // MARK: - Models
    
    struct ComparisonResults {
        let problem: String
        let approaches: [ApproachResult]
        let metrics: [MetricComparison]
        let winner: ReasoningComparisonView.ReasoningApproach?
        let timestamp: Date
        
        struct ApproachResult {
            let approach: ReasoningComparisonView.ReasoningApproach
            let reasoning: String
            let reasoningContent: String?
            let solution: String
            let metrics: [MetricValue]
            let strengths: [String]
            let weaknesses: [String]
            
            struct MetricValue {
                let type: ReasoningComparisonView.MetricType
                let value: Double
                let rawValue: String
            }
        }
        
        struct MetricComparison {
            let type: ReasoningComparisonView.MetricType
            let values: [ApproachValue]
            let bestApproach: ReasoningComparisonView.ReasoningApproach
            
            struct ApproachValue {
                let approach: ReasoningComparisonView.ReasoningApproach
                let value: Double
                let normalized: Double // 0-1 scale
            }
        }
    }
    
    struct Insight {
        let title: String
        let description: String
        let type: InsightType
        let relatedApproaches: [ReasoningComparisonView.ReasoningApproach]
        
        enum InsightType {
            case recommendation
            case tradeoff
            case unexpected
            case synergy
            
            var icon: String {
                switch self {
                case .recommendation: return "star.fill"
                case .tradeoff: return "arrow.left.arrow.right"
                case .unexpected: return "exclamationmark.bubble"
                case .synergy: return "link.circle"
                }
            }
            
            var color: Color {
                switch self {
                case .recommendation: return .yellow
                case .tradeoff: return .orange
                case .unexpected: return .purple
                case .synergy: return .green
                }
            }
        }
    }
    
    init(apiKey: String = "your-api-key") {
        self.client = DeepSeekClient(apiKey: apiKey)
    }
    
    // MARK: - Comparison Logic
    
    @MainActor
    func compare(
        problem: String,
        approaches: [ReasoningComparisonView.ReasoningApproach],
        mode: ReasoningComparisonView.ComparisonMode
    ) async {
        isComparing = true
        insights.removeAll()
        
        // Run each approach
        var approachResults: [ComparisonResults.ApproachResult] = []
        
        for approach in approaches {
            if let result = await runApproach(problem: problem, approach: approach, metrics: mode.metrics) {
                approachResults.append(result)
            }
        }
        
        // Compare metrics
        let metricComparisons = compareMetrics(
            results: approachResults,
            metrics: mode.metrics
        )
        
        // Determine winner
        let winner = determineWinner(
            comparisons: metricComparisons,
            mode: mode
        )
        
        // Generate insights
        insights = generateInsights(
            results: approachResults,
            comparisons: metricComparisons,
            mode: mode
        )
        
        comparisonResults = ComparisonResults(
            problem: problem,
            approaches: approachResults,
            metrics: metricComparisons,
            winner: winner,
            timestamp: Date()
        )
        
        isComparing = false
    }
    
    private func runApproach(
        problem: String,
        approach: ReasoningComparisonView.ReasoningApproach,
        metrics: [ReasoningComparisonView.MetricType]
    ) async -> ComparisonResults.ApproachResult? {
        let startTime = Date()
        
        let systemPrompt = createSystemPrompt(for: approach)
        let userPrompt = """
        Solve this problem using the \(approach.rawValue) approach:
        
        \(problem)
        
        Show your reasoning process clearly.
        """
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: systemPrompt),
                    Message(role: .user, content: userPrompt)
                ],
                temperature: temperatureForApproach(approach)
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                let processingTime = Date().timeIntervalSince(startTime)
                
                return createApproachResult(
                    approach: approach,
                    response: choice,
                    usage: response.usage,
                    processingTime: processingTime,
                    requestedMetrics: metrics
                )
            }
        } catch {
            print("Error running approach \(approach): \(error)")
        }
        
        return nil
    }
    
    private func createSystemPrompt(for approach: ReasoningComparisonView.ReasoningApproach) -> String {
        switch approach {
        case .stepByStep:
            return """
            You are a methodical problem solver. Break down problems into clear, sequential steps.
            Number each step and show how it leads to the next. Be thorough and systematic.
            """
            
        case .analytical:
            return """
            You are an analytical thinker. Deeply analyze all aspects of the problem.
            Consider multiple perspectives, identify key factors, and provide detailed analysis.
            """
            
        case .intuitive:
            return """
            You are an intuitive problem solver. Look for patterns and insights.
            Trust your instincts while explaining the reasoning behind your intuitions.
            """
            
        case .systematic:
            return """
            You are a systematic thinker. Use structured methodologies and frameworks.
            Apply proven problem-solving techniques and organize your approach clearly.
            """
            
        case .creative:
            return """
            You are a creative problem solver. Think outside the box and propose innovative solutions.
            Don't be constrained by conventional approaches. Explore novel ideas.
            """
        }
    }
    
    private func temperatureForApproach(_ approach: ReasoningComparisonView.ReasoningApproach) -> Double {
        switch approach {
        case .stepByStep, .systematic:
            return 0.3
        case .analytical:
            return 0.4
        case .intuitive:
            return 0.6
        case .creative:
            return 0.8
        }
    }
    
    private func createApproachResult(
        approach: ReasoningComparisonView.ReasoningApproach,
        response: ChatCompletionResponse.Choice,
        usage: ChatCompletionResponse.Usage?,
        processingTime: TimeInterval,
        requestedMetrics: [ReasoningComparisonView.MetricType]
    ) -> ComparisonResults.ApproachResult {
        let content = response.message.content
        let reasoningContent = response.message.reasoningContent
        
        // Extract solution from content
        let solution = extractSolution(from: content)
        
        // Calculate metrics
        let metrics = calculateMetrics(
            content: content,
            reasoningContent: reasoningContent,
            usage: usage,
            processingTime: processingTime,
            requestedMetrics: requestedMetrics
        )
        
        // Analyze strengths and weaknesses
        let (strengths, weaknesses) = analyzeApproach(
            approach: approach,
            content: content,
            metrics: metrics
        )
        
        return ComparisonResults.ApproachResult(
            approach: approach,
            reasoning: reasoningContent ?? content,
            reasoningContent: reasoningContent,
            solution: solution,
            metrics: metrics,
            strengths: strengths,
            weaknesses: weaknesses
        )
    }
    
    // MARK: - Metric Calculation
    
    private func calculateMetrics(
        content: String,
        reasoningContent: String?,
        usage: ChatCompletionResponse.Usage?,
        processingTime: TimeInterval,
        requestedMetrics: [ReasoningComparisonView.MetricType]
    ) -> [ComparisonResults.ApproachResult.MetricValue] {
        var metrics: [ComparisonResults.ApproachResult.MetricValue] = []
        
        for metricType in requestedMetrics {
            let value: Double
            let rawValue: String
            
            switch metricType {
            case .accuracy:
                // Simulated accuracy based on content analysis
                value = analyzeAccuracy(content: content)
                rawValue = "\(Int(value))%"
                
            case .clarity:
                value = analyzeClarity(content: content)
                rawValue = "\(Int(value))%"
                
            case .completeness:
                value = analyzeCompleteness(content: content)
                rawValue = "\(Int(value))%"
                
            case .speed:
                value = processingTime
                rawValue = String(format: "%.2fs", processingTime)
                
            case .tokenUsage:
                value = Double(usage?.totalTokens ?? 0)
                rawValue = "\(Int(value)) tokens"
                
            case .efficiency:
                let tokens = Double(usage?.totalTokens ?? 1)
                value = min(100, (1000 / tokens) * 100) // Inverse relationship
                rawValue = "\(Int(value))%"
                
            case .tokenCost:
                let tokens = Double(usage?.totalTokens ?? 0)
                value = tokens * 0.001 // $0.001 per token
                rawValue = String(format: "$%.4f", value)
                
            case .timeValue:
                // Cost per hour of processing
                value = (value / processingTime) * 3600
                rawValue = String(format: "$%.2f/hr", value)
                
            case .roi:
                // Return on investment (quality vs cost)
                let quality = (analyzeAccuracy(content: content) + analyzeClarity(content: content) + analyzeCompleteness(content: content)) / 3
                let cost = Double(usage?.totalTokens ?? 1) * 0.001
                value = min(100, (quality / max(cost, 0.01)) * 10)
                rawValue = "\(Int(value))%"
            }
            
            metrics.append(ComparisonResults.ApproachResult.MetricValue(
                type: metricType,
                value: value,
                rawValue: rawValue
            ))
        }
        
        return metrics
    }
    
    private func analyzeAccuracy(content: String) -> Double {
        // Simplified accuracy analysis
        var score = 70.0
        
        if content.contains("verify") || content.contains("check") {
            score += 10
        }
        if content.contains("correct") || content.contains("accurate") {
            score += 5
        }
        if content.contains("error") || content.contains("mistake") {
            score -= 10
        }
        
        return min(100, max(0, score))
    }
    
    private func analyzeClarity(content: String) -> Double {
        var score = 60.0
        
        // Check for structure
        if content.contains("Step") || content.contains("First") {
            score += 15
        }
        
        // Check for explanations
        if content.contains("because") || content.contains("therefore") {
            score += 10
        }
        
        // Penalize for complexity
        let avgWordLength = content.split(separator: " ").map { $0.count }.reduce(0, +) / max(content.split(separator: " ").count, 1)
        if avgWordLength > 8 {
            score -= 10
        }
        
        return min(100, max(0, score))
    }
    
    private func analyzeCompleteness(content: String) -> Double {
        var score = 50.0
        
        // Check for key elements
        let elements = ["problem", "solution", "approach", "result", "conclusion"]
        for element in elements {
            if content.lowercased().contains(element) {
                score += 10
            }
        }
        
        return min(100, max(0, score))
    }
    
    // MARK: - Comparison Analysis
    
    private func compareMetrics(
        results: [ComparisonResults.ApproachResult],
        metrics: [ReasoningComparisonView.MetricType]
    ) -> [ComparisonResults.MetricComparison] {
        var comparisons: [ComparisonResults.MetricComparison] = []
        
        for metricType in metrics {
            var approachValues: [ComparisonResults.MetricComparison.ApproachValue] = []
            
            // Get values for each approach
            for result in results {
                if let metric = result.metrics.first(where: { $0.type == metricType }) {
                    approachValues.append(ComparisonResults.MetricComparison.ApproachValue(
                        approach: result.approach,
                        value: metric.value,
                        normalized: 0 // Will calculate
                    ))
                }
            }
            
            // Normalize values
            if !approachValues.isEmpty {
                let maxValue = approachValues.map { $0.value }.max() ?? 1
                let minValue = approachValues.map { $0.value }.min() ?? 0
                let range = maxValue - minValue
                
                approachValues = approachValues.map { value in
                    let normalized: Double
                    if range > 0 {
                        // For metrics where lower is better (speed, cost, tokens)
                        if [.speed, .tokenUsage, .tokenCost].contains(metricType) {
                            normalized = 1 - ((value.value - minValue) / range)
                        } else {
                            normalized = (value.value - minValue) / range
                        }
                    } else {
                        normalized = 1.0
                    }
                    
                    return ComparisonResults.MetricComparison.ApproachValue(
                        approach: value.approach,
                        value: value.value,
                        normalized: normalized
                    )
                }
                
                // Find best approach
                let bestApproach = approachValues.max(by: { $0.normalized < $1.normalized })?.approach ?? results[0].approach
                
                comparisons.append(ComparisonResults.MetricComparison(
                    type: metricType,
                    values: approachValues,
                    bestApproach: bestApproach
                ))
            }
        }
        
        return comparisons
    }
    
    private func determineWinner(
        comparisons: [ComparisonResults.MetricComparison],
        mode: ReasoningComparisonView.ComparisonMode
    ) -> ReasoningComparisonView.ReasoningApproach? {
        var scores: [ReasoningComparisonView.ReasoningApproach: Double] = [:]
        
        // Calculate weighted scores
        for comparison in comparisons {
            let weight = weightForMetric(comparison.type, mode: mode)
            
            for value in comparison.values {
                scores[value.approach, default: 0] += value.normalized * weight
            }
        }
        
        // Find approach with highest score
        return scores.max(by: { $0.value < $1.value })?.key
    }
    
    private func weightForMetric(
        _ metric: ReasoningComparisonView.MetricType,
        mode: ReasoningComparisonView.ComparisonMode
    ) -> Double {
        switch mode {
        case .quality:
            switch metric {
            case .accuracy: return 0.4
            case .clarity: return 0.3
            case .completeness: return 0.3
            default: return 0.1
            }
            
        case .performance:
            switch metric {
            case .speed: return 0.4
            case .efficiency: return 0.4
            case .tokenUsage: return 0.2
            default: return 0.1
            }
            
        case .cost:
            switch metric {
            case .tokenCost: return 0.5
            case .roi: return 0.3
            case .timeValue: return 0.2
            default: return 0.1
            }
            
        case .comprehensive:
            return 1.0 / Double(ReasoningComparisonView.MetricType.allCases.count)
        }
    }
    
    // MARK: - Insight Generation
    
    private func generateInsights(
        results: [ComparisonResults.ApproachResult],
        comparisons: [ComparisonResults.MetricComparison],
        mode: ReasoningComparisonView.ComparisonMode
    ) -> [Insight] {
        var insights: [Insight] = []
        
        // Find best overall approach
        if let winner = determineWinner(comparisons: comparisons, mode: mode) {
            insights.append(Insight(
                title: "Best Overall: \(winner.rawValue)",
                description: "Based on \(mode.rawValue) criteria, the \(winner.rawValue) approach performs best",
                type: .recommendation,
                relatedApproaches: [winner]
            ))
        }
        
        // Find tradeoffs
        for comparison in comparisons {
            if comparison.values.count >= 2 {
                let sorted = comparison.values.sorted { $0.normalized > $1.normalized }
                if let best = sorted.first, let worst = sorted.last {
                    if best.normalized - worst.normalized > 0.3 {
                        insights.append(Insight(
                            title: "\(comparison.type.rawValue) Tradeoff",
                            description: "\(best.approach.rawValue) excels at \(comparison.type.rawValue) while \(worst.approach.rawValue) struggles",
                            type: .tradeoff,
                            relatedApproaches: [best.approach, worst.approach]
                        ))
                    }
                }
            }
        }
        
        // Find unexpected results
        for result in results {
            if result.approach == .creative {
                if let accuracyMetric = result.metrics.first(where: { $0.type == .accuracy }),
                   accuracyMetric.value > 80 {
                    insights.append(Insight(
                        title: "Creative Yet Accurate",
                        description: "The creative approach achieved high accuracy despite its unconventional nature",
                        type: .unexpected,
                        relatedApproaches: [result.approach]
                    ))
                }
            }
        }
        
        // Find synergies
        if results.count >= 2 {
            let approaches = results.map { $0.approach }
            if approaches.contains(.analytical) && approaches.contains(.systematic) {
                insights.append(Insight(
                    title: "Complementary Approaches",
                    description: "Analytical and Systematic approaches could be combined for comprehensive analysis",
                    type: .synergy,
                    relatedApproaches: [.analytical, .systematic]
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Helper Methods
    
    private func extractSolution(from content: String) -> String {
        // Look for solution markers
        let markers = ["solution:", "answer:", "recommendation:", "conclusion:"]
        
        for marker in markers {
            if let range = content.lowercased().range(of: marker) {
                let afterMarker = content[range.upperBound...]
                if let nextMarker = afterMarker.firstIndex(of: "\n\n") {
                    return String(afterMarker[..<nextMarker]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return String(afterMarker).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Return last paragraph as solution
        let paragraphs = content.components(separatedBy: "\n\n")
        return paragraphs.last ?? content
    }
    
    private func analyzeApproach(
        approach: ReasoningComparisonView.ReasoningApproach,
        content: String,
        metrics: [ComparisonResults.ApproachResult.MetricValue]
    ) -> (strengths: [String], weaknesses: [String]) {
        var strengths: [String] = []
        var weaknesses: [String] = []
        
        // Analyze based on approach type
        switch approach {
        case .stepByStep:
            if content.contains("Step") {
                strengths.append("Clear sequential structure")
            }
            if let speedMetric = metrics.first(where: { $0.type == .speed }),
               speedMetric.value > 3 {
                weaknesses.append("Can be time-consuming")
            }
            
        case .analytical:
            if content.contains("analysis") || content.contains("examine") {
                strengths.append("Thorough examination")
            }
            if let clarityMetric = metrics.first(where: { $0.type == .clarity }),
               clarityMetric.value < 70 {
                weaknesses.append("May be overly complex")
            }
            
        case .intuitive:
            if let speedMetric = metrics.first(where: { $0.type == .speed }),
               speedMetric.value < 2 {
                strengths.append("Quick insights")
            }
            weaknesses.append("May lack detailed justification")
            
        case .systematic:
            strengths.append("Consistent methodology")
            if let efficiencyMetric = metrics.first(where: { $0.type == .efficiency }),
               efficiencyMetric.value < 60 {
                weaknesses.append("Can be resource-intensive")
            }
            
        case .creative:
            strengths.append("Innovative solutions")
            weaknesses.append("Results may vary")
        }
        
        return (strengths, weaknesses)
    }
}

// MARK: - UI Components

struct ProblemInputSection: View {
    @Binding var problem: String
    let onLoadExample: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Problem Statement", systemImage: "questionmark.circle")
                    .font(.headline)
                
                Spacer()
                
                Button("Load Example", action: onLoadExample)
                    .font(.caption)
            }
            
            TextEditor(text: $problem)
                .font(.body)
                .frame(height: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct ApproachSelector: View {
    @Binding var selectedApproaches: Set<ReasoningComparisonView.ReasoningApproach>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Select Approaches", systemImage: "brain")
                    .font(.headline)
                
                Spacer()
                
                Text("\(selectedApproaches.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Choose at least 2 approaches to compare")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(ReasoningComparisonView.ReasoningApproach.allCases, id: \.self) { approach in
                    ApproachOption(
                        approach: approach,
                        isSelected: selectedApproaches.contains(approach),
                        onToggle: {
                            if selectedApproaches.contains(approach) {
                                selectedApproaches.remove(approach)
                            } else {
                                selectedApproaches.insert(approach)
                            }
                        }
                    )
                }
            }
        }
    }
}

struct ApproachOption: View {
    let approach: ReasoningComparisonView.ReasoningApproach
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? approach.color : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(approach.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(approach.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? approach.color.opacity(0.1) : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ComparisonModeSelector: View {
    @Binding var selectedMode: ReasoningComparisonView.ComparisonMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparison Focus")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(ReasoningComparisonView.ComparisonMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        action: { selectedMode = mode }
                    )
                }
            }
            
            // Show included metrics
            FlowLayout(spacing: 4) {
                ForEach(selectedMode.metrics, id: \.self) { metric in
                    MetricChip(metric: metric)
                }
            }
        }
    }
}

struct ModeButton: View {
    let mode: ReasoningComparisonView.ComparisonMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(mode.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

struct MetricChip: View {
    let metric: ReasoningComparisonView.MetricType
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: metric.icon)
                .font(.caption2)
            Text(metric.rawValue)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ComparisonResultsView: View {
    let results: ReasoningComparator.ComparisonResults
    let mode: ReasoningComparisonView.ComparisonMode
    @State private var selectedApproach: ReasoningComparisonView.ReasoningApproach?
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Winner announcement
            if let winner = results.winner {
                WinnerCard(winner: winner, mode: mode)
            }
            
            // Metric comparisons
            MetricComparisonChart(
                comparisons: results.metrics,
                onSelectApproach: { approach in
                    selectedApproach = approach
                    showingDetails = true
                }
            )
            
            // Approach cards
            VStack(spacing: 12) {
                ForEach(results.approaches, id: \.approach) { approachResult in
                    ApproachResultCard(
                        result: approachResult,
                        isWinner: approachResult.approach == results.winner,
                        onTap: {
                            selectedApproach = approachResult.approach
                            showingDetails = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showingDetails) {
            if let approach = selectedApproach,
               let result = results.approaches.first(where: { $0.approach == approach }) {
                ApproachDetailView(
                    approach: approach,
                    result: result,
                    metrics: results.metrics
                )
            }
        }
    }
}

struct WinnerCard: View {
    let winner: ReasoningComparisonView.ReasoningApproach
    let mode: ReasoningComparisonView.ComparisonMode
    
    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Best for \(mode.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(winner.rawValue)
                    .font(.headline)
                    .foregroundColor(winner.color)
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [winner.color.opacity(0.2), winner.color.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }
}

struct MetricComparisonChart: View {
    let comparisons: [ReasoningComparator.ComparisonResults.MetricComparison]
    let onSelectApproach: (ReasoningComparisonView.ReasoningApproach) -> Void
    @State private var selectedMetric: ReasoningComparisonView.MetricType?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metric Comparison")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(comparisons, id: \.type) { comparison in
                        MetricComparisonCard(
                            comparison: comparison,
                            isSelected: selectedMetric == comparison.type,
                            onTap: { selectedMetric = comparison.type },
                            onSelectApproach: onSelectApproach
                        )
                    }
                }
            }
        }
    }
}

struct MetricComparisonCard: View {
    let comparison: ReasoningComparator.ComparisonResults.MetricComparison
    let isSelected: Bool
    let onTap: () -> Void
    let onSelectApproach: (ReasoningComparisonView.ReasoningApproach) -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: comparison.type.icon)
                        .foregroundColor(.blue)
                    
                    Text(comparison.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                // Bars
                VStack(spacing: 4) {
                    ForEach(comparison.values, id: \.approach) { value in
                        HStack(spacing: 8) {
                            Text(String(value.approach.rawValue.prefix(3)))
                                .font(.caption2)
                                .frame(width: 30, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 20)
                                    
                                    Rectangle()
                                        .fill(value.approach == comparison.bestApproach ? Color.green : value.approach.color)
                                        .frame(width: geometry.size.width * value.normalized, height: 20)
                                }
                                .cornerRadius(4)
                            }
                            .frame(height: 20)
                            
                            Text(formatValue(value.value, type: comparison.type))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .onTapGesture {
                            onSelectApproach(value.approach)
                        }
                    }
                }
            }
            .padding()
            .frame(width: 250)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
    
    private func formatValue(_ value: Double, type: ReasoningComparisonView.MetricType) -> String {
        switch type {
        case .accuracy, .clarity, .completeness, .efficiency, .roi:
            return "\(Int(value))%"
        case .speed:
            return String(format: "%.1fs", value)
        case .tokenUsage:
            return "\(Int(value))"
        case .tokenCost:
            return String(format: "$%.3f", value)
        case .timeValue:
            return String(format: "$%.1f", value)
        }
    }
}

struct ApproachResultCard: View {
    let result: ReasoningComparator.ComparisonResults.ApproachResult
    let isWinner: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Circle()
                        .fill(result.approach.color)
                        .frame(width: 12, height: 12)
                    
                    Text(result.approach.rawValue)
                        .font(.headline)
                    
                    if isWinner {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Key metrics
                HStack(spacing: 16) {
                    ForEach(result.metrics.prefix(3), id: \.type) { metric in
                        VStack(spacing: 2) {
                            Text(metric.rawValue)
                                .font(.caption2)
                                .fontWeight(.semibold)
                            
                            Image(systemName: metric.type.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Strengths & Weaknesses
                HStack(alignment: .top, spacing: 16) {
                    if !result.strengths.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Strengths", systemImage: "plus.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            
                            ForEach(result.strengths, id: \.self) { strength in
                                Text("• \(strength)")
                                    .font(.caption2)
                            }
                        }
                    }
                    
                    if !result.weaknesses.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Weaknesses", systemImage: "minus.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            
                            ForEach(result.weaknesses, id: \.self) { weakness in
                                Text("• \(weakness)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isWinner ? result.approach.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isWinner ? result.approach.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InsightsSection: View {
    let insights: [ReasoningComparator.Insight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Insights", systemImage: "lightbulb.fill")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(insights.indices, id: \.self) { index in
                    InsightCard(insight: insights[index])
                }
            }
        }
    }
}

struct InsightCard: View {
    let insight: ReasoningComparator.Insight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.type.icon)
                .font(.body)
                .foregroundColor(insight.type.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !insight.relatedApproaches.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(insight.relatedApproaches, id: \.self) { approach in
                            Text(approach.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(approach.color.opacity(0.2))
                                .foregroundColor(approach.color)
                                .cornerRadius(4)
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

struct ApproachDetailView: View {
    let approach: ReasoningComparisonView.ReasoningApproach
    let result: ReasoningComparator.ComparisonResults.ApproachResult
    let metrics: [ReasoningComparator.ComparisonResults.MetricComparison]
    @Environment(\.dismiss) var dismiss
    @State private var showingReasoning = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Approach info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(approach.color)
                                .frame(width: 16, height: 16)
                            
                            Text(approach.rawValue)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text(approach.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Metrics")
                            .font(.headline)
                        
                        ForEach(result.metrics, id: \.type) { metric in
                            MetricRow(metric: metric, comparisons: metrics)
                        }
                    }
                    
                    // Solution
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Solution")
                            .font(.headline)
                        
                        Text(result.solution)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Reasoning
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { showingReasoning.toggle() }) {
                            HStack {
                                Text("Reasoning Process")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Image(systemName: showingReasoning ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.primary)
                        
                        if showingReasoning {
                            ScrollView {
                                Text(result.reasoning)
                                    .font(.caption)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .frame(maxHeight: 300)
                        }
                    }
                    
                    // Strengths & Weaknesses
                    HStack(alignment: .top, spacing: 16) {
                        if !result.strengths.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Strengths", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(result.strengths, id: \.self) { strength in
                                        HStack(alignment: .top, spacing: 4) {
                                            Text("•")
                                            Text(strength)
                                        }
                                        .font(.body)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        
                        if !result.weaknesses.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Weaknesses", systemImage: "minus.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(result.weaknesses, id: \.self) { weakness in
                                        HStack(alignment: .top, spacing: 4) {
                                            Text("•")
                                            Text(weakness)
                                        }
                                        .font(.body)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Approach Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MetricRow: View {
    let metric: ReasoningComparator.ComparisonResults.ApproachResult.MetricValue
    let comparisons: [ReasoningComparator.ComparisonResults.MetricComparison]
    
    var percentile: Double? {
        guard let comparison = comparisons.first(where: { $0.type == metric.type }),
              let value = comparison.values.first(where: { $0.value == metric.value }) else {
            return nil
        }
        return value.normalized
    }
    
    var body: some View {
        HStack {
            Image(systemName: metric.type.icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(metric.type.rawValue)
                .font(.subheadline)
            
            Spacer()
            
            Text(metric.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let percentile = percentile {
                PercentileIndicator(value: percentile)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PercentileIndicator: View {
    let value: Double
    
    var color: Color {
        if value >= 0.8 { return .green }
        if value >= 0.5 { return .orange }
        return .red
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 20, height: 20)
            
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, lineWidth: 2)
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(-90))
        }
    }
}

// Flow Layout (reused from previous file)
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for size in sizes {
            if currentRowWidth + size.width + spacing > proposal.width ?? .infinity {
                totalHeight += size.height + spacing
                maxWidth = max(maxWidth, currentRowWidth)
                currentRowWidth = size.width
            } else {
                currentRowWidth += size.width + spacing
            }
        }
        
        totalHeight += sizes.last?.height ?? 0
        maxWidth = max(maxWidth, currentRowWidth)
        
        return CGSize(width: maxWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var currentX = bounds.minX
        var currentY = bounds.minY
        
        for (index, subview) in subviews.enumerated() {
            let size = sizes[index]
            
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += size.height + spacing
            }
            
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            
            currentX += size.width + spacing
        }
    }
}

// MARK: - Demo

struct ReasoningComparisonDemo: View {
    var body: some View {
        ReasoningComparisonView()
    }
}