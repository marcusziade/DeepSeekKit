import SwiftUI
import DeepSeekKit

// Optimize reasoning efficiency
struct ReasoningOptimizerView: View {
    @StateObject private var optimizer = ReasoningOptimizer()
    @State private var reasoningInput = ""
    @State private var optimizationGoal: OptimizationGoal = .balanced
    @State private var selectedStrategies: Set<OptimizationStrategy> = [.simplification, .parallelization]
    @State private var showingComparison = false
    
    enum OptimizationGoal: String, CaseIterable {
        case speed = "Speed"
        case accuracy = "Accuracy"
        case clarity = "Clarity"
        case balanced = "Balanced"
        case tokenEfficiency = "Token Efficiency"
        
        var description: String {
            switch self {
            case .speed: return "Minimize reasoning time"
            case .accuracy: return "Maximize correctness"
            case .clarity: return "Improve understandability"
            case .balanced: return "Balance all factors"
            case .tokenEfficiency: return "Reduce token usage"
            }
        }
        
        var icon: String {
            switch self {
            case .speed: return "speedometer"
            case .accuracy: return "target"
            case .clarity: return "eye"
            case .balanced: return "scale.3d"
            case .tokenEfficiency: return "doc.text"
            }
        }
        
        var color: Color {
            switch self {
            case .speed: return .green
            case .accuracy: return .blue
            case .clarity: return .purple
            case .balanced: return .orange
            case .tokenEfficiency: return .red
            }
        }
    }
    
    enum OptimizationStrategy: String, CaseIterable {
        case simplification = "Simplification"
        case parallelization = "Parallelization"
        case caching = "Result Caching"
        case pruning = "Branch Pruning"
        case batching = "Step Batching"
        case memoization = "Memoization"
        
        var description: String {
            switch self {
            case .simplification: return "Remove redundant steps"
            case .parallelization: return "Execute independent steps in parallel"
            case .caching: return "Cache intermediate results"
            case .pruning: return "Remove unnecessary branches"
            case .batching: return "Combine similar operations"
            case .memoization: return "Reuse previous computations"
            }
        }
        
        var expectedImprovement: String {
            switch self {
            case .simplification: return "10-30% reduction"
            case .parallelization: return "40-60% speedup"
            case .caching: return "20-50% efficiency"
            case .pruning: return "15-35% reduction"
            case .batching: return "25-40% efficiency"
            case .memoization: return "30-70% speedup"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Input section
                OptimizationInputSection(
                    reasoning: $reasoningInput,
                    onLoadBenchmark: loadBenchmarkReasoning
                )
                
                // Goal selection
                GoalSelectionView(
                    selectedGoal: $optimizationGoal,
                    onChange: { optimizer.currentGoal = $0 }
                )
                
                // Strategy selection
                StrategySelectionView(
                    selectedStrategies: $selectedStrategies,
                    goal: optimizationGoal
                )
                
                // Optimize button
                Button(action: performOptimization) {
                    if optimizer.isOptimizing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Label("Optimize Reasoning", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(reasoningInput.isEmpty || optimizer.isOptimizing)
                
                // Current optimization
                if let result = optimizer.currentResult {
                    OptimizationResultView(
                        result: result,
                        onCompare: { showingComparison = true }
                    )
                }
                
                // Performance metrics
                if let metrics = optimizer.performanceMetrics {
                    PerformanceMetricsView(metrics: metrics)
                }
                
                // Optimization history
                if !optimizer.optimizationHistory.isEmpty {
                    OptimizationHistoryView(
                        history: optimizer.optimizationHistory,
                        onSelect: { result in
                            optimizer.currentResult = result
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Reasoning Optimizer")
        .sheet(isPresented: $showingComparison) {
            if let result = optimizer.currentResult {
                OptimizationComparisonView(
                    original: reasoningInput,
                    optimized: result.optimizedReasoning,
                    metrics: result.metrics
                )
            }
        }
    }
    
    private func performOptimization() {
        Task {
            await optimizer.optimizeReasoning(
                reasoningInput,
                goal: optimizationGoal,
                strategies: Array(selectedStrategies)
            )
        }
    }
    
    private func loadBenchmarkReasoning() {
        reasoningInput = """
        To solve the traveling salesman problem for 5 cities:
        
        Step 1: Calculate all pairwise distances
        - Distance A to B: 10
        - Distance A to C: 15
        - Distance A to D: 20
        - Distance A to E: 25
        - Distance B to C: 12
        - Distance B to D: 18
        - Distance B to E: 22
        - Distance C to D: 8
        - Distance C to E: 14
        - Distance D to E: 16
        
        Step 2: Generate all possible routes starting from A
        - Route 1: A → B → C → D → E → A
        - Route 2: A → B → C → E → D → A
        - Route 3: A → B → D → C → E → A
        - ... (continue for all 24 permutations)
        
        Step 3: Calculate total distance for each route
        - Route 1: 10 + 12 + 8 + 16 + 25 = 71
        - Route 2: 10 + 12 + 14 + 16 + 20 = 72
        - ... (calculate for all routes)
        
        Step 4: Find the minimum distance route
        
        This brute force approach has O(n!) complexity.
        """
    }
}

// MARK: - Reasoning Optimizer Engine

class ReasoningOptimizer: ObservableObject {
    @Published var currentResult: OptimizationResult?
    @Published var performanceMetrics: PerformanceMetrics?
    @Published var optimizationHistory: [OptimizationResult] = []
    @Published var isOptimizing = false
    @Published var currentGoal: ReasoningOptimizerView.OptimizationGoal = .balanced
    
    private let client: DeepSeekClient
    
    init() {
        self.client = DeepSeekClient(apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "")
    }
    
    func optimizeReasoning(_ reasoning: String, goal: ReasoningOptimizerView.OptimizationGoal, strategies: [ReasoningOptimizerView.OptimizationStrategy]) async {
        await MainActor.run { isOptimizing = true }
        
        let startTime = Date()
        let originalTokens = estimateTokens(reasoning)
        
        do {
            let messages: [Message] = [
                Message(role: .system, content: """
                    You are an expert at optimizing reasoning processes for efficiency and clarity.
                    
                    Optimization Goal: \(goal.rawValue) - \(goal.description)
                    
                    Apply these strategies:
                    \(strategies.map { "- \($0.rawValue): \($0.description)" }.joined(separator: "\n"))
                    
                    Provide:
                    1. Optimized reasoning steps
                    2. Specific optimizations applied
                    3. Performance improvements
                    4. Trade-offs made
                    """),
                Message(role: .user, content: "Optimize this reasoning:\n\n\(reasoning)")
            ]
            
            let params = ChatCompletionParameters(
                model: "deepseek-reasoner",
                messages: messages,
                temperature: 0.1,
                maxTokens: 3000
            )
            
            let response = try await client.chatCompletion(params: params)
            
            if let content = response.choices.first?.message.content {
                let result = parseOptimizationResult(
                    content,
                    original: reasoning,
                    goal: goal,
                    strategies: strategies,
                    startTime: startTime,
                    originalTokens: originalTokens
                )
                
                await MainActor.run {
                    self.currentResult = result
                    self.performanceMetrics = result.metrics
                    self.optimizationHistory.append(result)
                    self.isOptimizing = false
                }
            }
        } catch {
            print("Error optimizing reasoning: \(error)")
            await MainActor.run { isOptimizing = false }
        }
    }
    
    private func parseOptimizationResult(_ content: String, original: String, goal: ReasoningOptimizerView.OptimizationGoal, strategies: [ReasoningOptimizerView.OptimizationStrategy], startTime: Date, originalTokens: Int) -> OptimizationResult {
        let optimizedReasoning = extractOptimizedReasoning(from: content)
        let optimizationsApplied = extractOptimizations(from: content)
        let improvements = extractImprovements(from: content)
        let tradeoffs = extractTradeoffs(from: content)
        
        let optimizedTokens = estimateTokens(optimizedReasoning)
        let processingTime = Date().timeIntervalSince(startTime)
        
        let metrics = PerformanceMetrics(
            originalTokens: originalTokens,
            optimizedTokens: optimizedTokens,
            tokenReduction: Double(originalTokens - optimizedTokens) / Double(originalTokens),
            estimatedSpeedup: calculateSpeedup(from: improvements),
            clarityScore: calculateClarityScore(from: content),
            accuracyImpact: calculateAccuracyImpact(from: tradeoffs),
            processingTime: processingTime
        )
        
        return OptimizationResult(
            id: UUID().uuidString,
            originalReasoning: original,
            optimizedReasoning: optimizedReasoning,
            goal: goal,
            strategies: strategies,
            optimizationsApplied: optimizationsApplied,
            improvements: improvements,
            tradeoffs: tradeoffs,
            metrics: metrics,
            timestamp: Date()
        )
    }
    
    private func extractOptimizedReasoning(from content: String) -> String {
        if let section = extractSection("Optimized Reasoning", from: content) {
            return section
        }
        
        // Fallback: look for the main reasoning block
        let lines = content.components(separatedBy: "\n")
        var reasoningLines: [String] = []
        var inReasoning = false
        
        for line in lines {
            if line.contains("Step 1:") || line.contains("1.") || line.contains("First,") {
                inReasoning = true
            }
            
            if inReasoning {
                reasoningLines.append(line)
                
                if line.contains("Therefore") || line.contains("Conclusion") || line.contains("Result") {
                    break
                }
            }
        }
        
        return reasoningLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractOptimizations(from content: String) -> [AppliedOptimization] {
        var optimizations: [AppliedOptimization] = []
        
        if let section = extractSection("Optimizations Applied", from: content) {
            let lines = section.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for line in lines {
                if let optimization = parseOptimizationLine(line) {
                    optimizations.append(optimization)
                }
            }
        }
        
        return optimizations
    }
    
    private func parseOptimizationLine(_ line: String) -> AppliedOptimization? {
        let type = determineOptimizationType(from: line)
        let impact = extractImpact(from: line)
        
        return AppliedOptimization(
            type: type,
            description: line.replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "• ", with: ""),
            impact: impact,
            location: extractLocation(from: line)
        )
    }
    
    private func determineOptimizationType(from text: String) -> OptimizationType {
        let lowercased = text.lowercased()
        
        if lowercased.contains("simplif") || lowercased.contains("remov") || lowercased.contains("reduc") {
            return .simplification
        } else if lowercased.contains("parallel") || lowercased.contains("concurrent") {
            return .parallelization
        } else if lowercased.contains("cach") || lowercased.contains("stor") {
            return .caching
        } else if lowercased.contains("prun") || lowercased.contains("eliminat") {
            return .pruning
        } else if lowercased.contains("batch") || lowercased.contains("combin") {
            return .batching
        } else if lowercased.contains("memo") || lowercased.contains("reus") {
            return .memoization
        } else {
            return .other
        }
    }
    
    private func extractImpact(from text: String) -> String {
        // Look for percentage improvements
        let pattern = #"(\d+%|\d+x|[\d.]+x)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range, in: text) {
                    return String(text[range])
                }
            }
        }
        
        return ""
    }
    
    private func extractLocation(from text: String) -> String? {
        if let stepMatch = text.range(of: "Step \\d+", options: .regularExpression) {
            return String(text[stepMatch])
        }
        return nil
    }
    
    private func extractImprovements(from content: String) -> [String] {
        if let section = extractSection("Performance Improvements", from: content) {
            return section.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && ($0.contains("-") || $0.contains("•")) }
                .map { $0.replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "• ", with: "") }
        }
        return []
    }
    
    private func extractTradeoffs(from content: String) -> [String] {
        if let section = extractSection("Trade-offs", from: content) {
            return section.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && ($0.contains("-") || $0.contains("•")) }
                .map { $0.replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "• ", with: "") }
        }
        return []
    }
    
    private func extractSection(_ section: String, from content: String) -> String? {
        if let sectionRange = content.range(of: "\(section):", options: .caseInsensitive) {
            let startIndex = sectionRange.upperBound
            let remainingContent = String(content[startIndex...])
            
            // Find next section
            let sections = ["Optimized Reasoning", "Optimizations Applied", "Performance Improvements", "Trade-offs"]
            var endIndex = remainingContent.endIndex
            
            for nextSection in sections {
                if nextSection != section {
                    if let nextRange = remainingContent.range(of: "\(nextSection):", options: .caseInsensitive) {
                        endIndex = min(endIndex, nextRange.lowerBound)
                    }
                }
            }
            
            return String(remainingContent[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func estimateTokens(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token
        return text.count / 4
    }
    
    private func calculateSpeedup(from improvements: [String]) -> Double {
        var totalSpeedup = 1.0
        
        for improvement in improvements {
            if let speedup = extractSpeedupValue(from: improvement) {
                totalSpeedup *= speedup
            }
        }
        
        return totalSpeedup
    }
    
    private func extractSpeedupValue(from text: String) -> Double? {
        let pattern = #"(\d+)%\s*(faster|speedup|improvement)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text),
                   let percentage = Double(text[range]) {
                    return 1.0 + (percentage / 100.0)
                }
            }
        }
        
        return nil
    }
    
    private func calculateClarityScore(from content: String) -> Double {
        var score = 0.5 // Base score
        
        let clarityIndicators = [
            "clearer": 0.1,
            "simplified": 0.1,
            "easier to understand": 0.15,
            "more readable": 0.1,
            "better organized": 0.1
        ]
        
        let lowercased = content.lowercased()
        for (indicator, boost) in clarityIndicators {
            if lowercased.contains(indicator) {
                score += boost
            }
        }
        
        return min(1.0, score)
    }
    
    private func calculateAccuracyImpact(from tradeoffs: [String]) -> Double {
        var impact = 0.0
        
        for tradeoff in tradeoffs {
            let lowercased = tradeoff.lowercased()
            if lowercased.contains("accuracy") || lowercased.contains("precision") {
                if lowercased.contains("slight") || lowercased.contains("minimal") {
                    impact -= 0.05
                } else if lowercased.contains("significant") || lowercased.contains("major") {
                    impact -= 0.2
                } else {
                    impact -= 0.1
                }
            }
        }
        
        return impact
    }
}

// MARK: - Data Models

struct OptimizationResult: Identifiable {
    let id: String
    let originalReasoning: String
    let optimizedReasoning: String
    let goal: ReasoningOptimizerView.OptimizationGoal
    let strategies: [ReasoningOptimizerView.OptimizationStrategy]
    let optimizationsApplied: [AppliedOptimization]
    let improvements: [String]
    let tradeoffs: [String]
    let metrics: PerformanceMetrics
    let timestamp: Date
}

struct AppliedOptimization: Identifiable {
    let id = UUID()
    let type: OptimizationType
    let description: String
    let impact: String
    let location: String?
}

enum OptimizationType {
    case simplification
    case parallelization
    case caching
    case pruning
    case batching
    case memoization
    case other
    
    var icon: String {
        switch self {
        case .simplification: return "minus.circle"
        case .parallelization: return "arrow.triangle.branch"
        case .caching: return "memorychip"
        case .pruning: return "scissors"
        case .batching: return "square.stack.3d.up"
        case .memoization: return "arrow.clockwise"
        case .other: return "ellipsis.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .simplification: return .blue
        case .parallelization: return .green
        case .caching: return .orange
        case .pruning: return .red
        case .batching: return .purple
        case .memoization: return .yellow
        case .other: return .gray
        }
    }
}

struct PerformanceMetrics {
    let originalTokens: Int
    let optimizedTokens: Int
    let tokenReduction: Double
    let estimatedSpeedup: Double
    let clarityScore: Double
    let accuracyImpact: Double
    let processingTime: TimeInterval
}

// MARK: - Supporting Views

struct OptimizationInputSection: View {
    @Binding var reasoning: String
    let onLoadBenchmark: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Reasoning to Optimize", systemImage: "doc.text")
                    .font(.headline)
                
                Spacer()
                
                Button("Load Benchmark", action: onLoadBenchmark)
                    .font(.caption)
            }
            
            TextEditor(text: $reasoning)
                .frame(height: 150)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Text("\(reasoning.count) characters • ~\(reasoning.count / 4) tokens")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct GoalSelectionView: View {
    @Binding var selectedGoal: ReasoningOptimizerView.OptimizationGoal
    let onChange: (ReasoningOptimizerView.OptimizationGoal) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Optimization Goal")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ReasoningOptimizerView.OptimizationGoal.allCases, id: \.self) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: selectedGoal == goal,
                            action: {
                                selectedGoal = goal
                                onChange(goal)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct GoalCard: View {
    let goal: ReasoningOptimizerView.OptimizationGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? goal.color : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: goal.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : goal.color)
                }
                
                Text(goal.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(goal.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StrategySelectionView: View {
    @Binding var selectedStrategies: Set<ReasoningOptimizerView.OptimizationStrategy>
    let goal: ReasoningOptimizerView.OptimizationGoal
    
    var recommendedStrategies: Set<ReasoningOptimizerView.OptimizationStrategy> {
        switch goal {
        case .speed:
            return [.parallelization, .caching, .pruning]
        case .accuracy:
            return [.memoization]
        case .clarity:
            return [.simplification, .batching]
        case .balanced:
            return [.simplification, .parallelization, .caching]
        case .tokenEfficiency:
            return [.simplification, .pruning, .batching]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Optimization Strategies")
                    .font(.headline)
                
                Spacer()
                
                Button("Use Recommended") {
                    selectedStrategies = recommendedStrategies
                }
                .font(.caption)
            }
            
            ForEach(ReasoningOptimizerView.OptimizationStrategy.allCases, id: \.self) { strategy in
                StrategyRow(
                    strategy: strategy,
                    isSelected: selectedStrategies.contains(strategy),
                    isRecommended: recommendedStrategies.contains(strategy),
                    action: {
                        if selectedStrategies.contains(strategy) {
                            selectedStrategies.remove(strategy)
                        } else {
                            selectedStrategies.insert(strategy)
                        }
                    }
                )
            }
        }
    }
}

struct StrategyRow: View {
    let strategy: ReasoningOptimizerView.OptimizationStrategy
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(strategy.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(strategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Expected: \(strategy.expectedImprovement)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OptimizationResultView: View {
    let result: OptimizationResult
    let onCompare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Optimization Complete", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("Compare", action: onCompare)
                    .font(.caption)
            }
            
            // Quick metrics
            HStack(spacing: 20) {
                MetricBadge(
                    title: "Token Reduction",
                    value: "\(Int(result.metrics.tokenReduction * 100))%",
                    color: .green
                )
                
                MetricBadge(
                    title: "Speed Boost",
                    value: String(format: "%.1fx", result.metrics.estimatedSpeedup),
                    color: .blue
                )
                
                MetricBadge(
                    title: "Clarity",
                    value: "\(Int(result.metrics.clarityScore * 100))%",
                    color: .purple
                )
            }
            
            // Optimizations applied
            if !result.optimizationsApplied.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optimizations Applied")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(result.optimizationsApplied) { optimization in
                        OptimizationCard(optimization: optimization)
                    }
                }
            }
            
            // Improvements
            if !result.improvements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Improvements")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(result.improvements, id: \.self) { improvement in
                        HStack(alignment: .top) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(improvement)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // Trade-offs
            if !result.tradeoffs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trade-offs")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    ForEach(result.tradeoffs, id: \.self) { tradeoff in
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(tradeoff)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
}

struct MetricBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct OptimizationCard: View {
    let optimization: AppliedOptimization
    
    var body: some View {
        HStack {
            Image(systemName: optimization.type.icon)
                .foregroundColor(optimization.type.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(optimization.description)
                    .font(.caption)
                
                HStack {
                    if let location = optimization.location {
                        Text(location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if !optimization.impact.isEmpty {
                        Text(optimization.impact)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(optimization.type.color.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PerformanceMetricsView: View {
    let metrics: PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detailed Metrics")
                .font(.headline)
            
            VStack(spacing: 12) {
                MetricRow(
                    label: "Original Tokens",
                    value: "\(metrics.originalTokens)",
                    detail: nil
                )
                
                MetricRow(
                    label: "Optimized Tokens",
                    value: "\(metrics.optimizedTokens)",
                    detail: "\(Int(metrics.tokenReduction * 100))% reduction",
                    detailColor: .green
                )
                
                MetricRow(
                    label: "Estimated Speedup",
                    value: String(format: "%.2fx", metrics.estimatedSpeedup),
                    detail: metrics.estimatedSpeedup > 1 ? "faster" : "slower",
                    detailColor: metrics.estimatedSpeedup > 1 ? .green : .red
                )
                
                MetricRow(
                    label: "Clarity Score",
                    value: "\(Int(metrics.clarityScore * 100))%",
                    detail: metrics.clarityScore > 0.7 ? "High" : metrics.clarityScore > 0.4 ? "Medium" : "Low"
                )
                
                if metrics.accuracyImpact != 0 {
                    MetricRow(
                        label: "Accuracy Impact",
                        value: String(format: "%.1f%%", metrics.accuracyImpact * 100),
                        detail: metrics.accuracyImpact < 0 ? "Trade-off" : "Maintained",
                        detailColor: metrics.accuracyImpact < 0 ? .orange : .green
                    )
                }
                
                MetricRow(
                    label: "Processing Time",
                    value: String(format: "%.2fs", metrics.processingTime),
                    detail: nil
                )
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let detail: String?
    var detailColor: Color = .secondary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let detail = detail {
                    Text("(\(detail))")
                        .font(.caption)
                        .foregroundColor(detailColor)
                }
            }
        }
    }
}

struct OptimizationComparisonView: View {
    let original: String
    let optimized: String
    let metrics: PerformanceMetrics
    @Environment(\.dismiss) var dismiss
    @State private var showDifferences = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Metrics summary
                    HStack(spacing: 16) {
                        ComparisonMetric(
                            title: "Tokens",
                            original: "\(metrics.originalTokens)",
                            optimized: "\(metrics.optimizedTokens)",
                            improvement: "-\(Int(metrics.tokenReduction * 100))%"
                        )
                        
                        ComparisonMetric(
                            title: "Speed",
                            original: "1.0x",
                            optimized: String(format: "%.1fx", metrics.estimatedSpeedup),
                            improvement: "+\(Int((metrics.estimatedSpeedup - 1) * 100))%"
                        )
                        
                        ComparisonMetric(
                            title: "Clarity",
                            original: "—",
                            optimized: "\(Int(metrics.clarityScore * 100))%",
                            improvement: nil
                        )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Toggle
                    Toggle("Highlight Differences", isOn: $showDifferences)
                        .padding(.horizontal)
                    
                    // Side-by-side comparison
                    HStack(alignment: .top, spacing: 16) {
                        // Original
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Original", systemImage: "doc.text")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            ScrollView {
                                Text(original)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                        }
                        
                        // Optimized
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Optimized", systemImage: "doc.text.fill")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            ScrollView {
                                if showDifferences {
                                    HighlightedText(
                                        text: optimized,
                                        original: original
                                    )
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text(optimized)
                                        .font(.system(.body, design: .monospaced))
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Optimization Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ComparisonMetric: View {
    let title: String
    let original: String
    let optimized: String
    let improvement: String?
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Text(original)
                    .font(.caption)
                    .foregroundColor(.red)
                
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(optimized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            
            if let improvement = improvement {
                Text(improvement)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(improvement.hasPrefix("+") ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct HighlightedText: View {
    let text: String
    let original: String
    
    var body: some View {
        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let originalWords = Set(original.split(separator: " ", omittingEmptySubsequences: false).map(String.init))
        
        return Text(buildAttributedString())
            .font(.system(.body, design: .monospaced))
    }
    
    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let originalWords = Set(original.split(separator: " ", omittingEmptySubsequences: false).map(String.init))
        
        for (index, word) in words.enumerated() {
            var attributedWord = AttributedString(word)
            
            if !originalWords.contains(word) {
                attributedWord.backgroundColor = .green.opacity(0.3)
            }
            
            result.append(attributedWord)
            
            if index < words.count - 1 {
                result.append(AttributedString(" "))
            }
        }
        
        return result
    }
}

struct OptimizationHistoryView: View {
    let history: [OptimizationResult]
    let onSelect: (OptimizationResult) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Optimization History")
                .font(.headline)
            
            ForEach(history.reversed()) { result in
                Button(action: { onSelect(result) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.goal.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 8) {
                                ForEach(result.strategies.prefix(3), id: \.self) { strategy in
                                    Text(strategy.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                if result.strategies.count > 3 {
                                    Text("+\(result.strategies.count - 3)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(result.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("-\(Int(result.metrics.tokenReduction * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text(String(format: "%.1fx", result.metrics.estimatedSpeedup))
                                .font(.caption2)
                                .foregroundColor(.blue)
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

// MARK: - App

struct ReasoningOptimizerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ReasoningOptimizerView()
            }
        }
    }
}