import SwiftUI
import DeepSeekKit

// Generate reasoning recommendations
struct ReasoningRecommenderView: View {
    @StateObject private var recommender = ReasoningRecommender()
    @State private var problemDescription = ""
    @State private var context = ""
    @State private var constraints: Set<Constraint> = []
    @State private var recommendationType: RecommendationType = .approach
    @State private var showingDetailedView = false
    
    enum RecommendationType: String, CaseIterable {
        case approach = "Reasoning Approach"
        case methodology = "Methodology"
        case framework = "Framework"
        case tools = "Tools & Techniques"
        case hybrid = "Hybrid Solution"
        
        var description: String {
            switch self {
            case .approach: return "Best reasoning strategies for your problem"
            case .methodology: return "Structured methods and processes"
            case .framework: return "Conceptual frameworks to apply"
            case .tools: return "Specific tools and techniques"
            case .hybrid: return "Combined approaches for complex problems"
            }
        }
        
        var icon: String {
            switch self {
            case .approach: return "brain"
            case .methodology: return "list.bullet.rectangle"
            case .framework: return "square.stack.3d.up"
            case .tools: return "wrench.and.screwdriver"
            case .hybrid: return "link.circle"
            }
        }
    }
    
    enum Constraint: String, CaseIterable {
        case timeLimit = "Time Constraints"
        case accuracy = "High Accuracy Required"
        case explainability = "Must Be Explainable"
        case scalability = "Must Scale"
        case realTime = "Real-time Processing"
        case limitedData = "Limited Data Available"
        
        var icon: String {
            switch self {
            case .timeLimit: return "clock"
            case .accuracy: return "target"
            case .explainability: return "text.bubble"
            case .scalability: return "arrow.up.right"
            case .realTime: return "bolt"
            case .limitedData: return "doc.text"
            }
        }
        
        var impact: String {
            switch self {
            case .timeLimit: return "Favors efficient approaches"
            case .accuracy: return "Requires thorough validation"
            case .explainability: return "Needs transparent reasoning"
            case .scalability: return "Must handle growing complexity"
            case .realTime: return "Requires fast decision-making"
            case .limitedData: return "Needs robust assumptions"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Problem input
                ProblemInputSection(
                    problem: $problemDescription,
                    context: $context,
                    onLoadExample: loadExampleProblem
                )
                
                // Constraints selection
                ConstraintsSelectionView(
                    selectedConstraints: $constraints,
                    onChange: { recommender.constraints = Array($0) }
                )
                
                // Recommendation type
                RecommendationTypeView(
                    selectedType: $recommendationType,
                    onChange: { recommender.recommendationType = $0 }
                )
                
                // Generate button
                Button(action: generateRecommendations) {
                    if recommender.isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Label("Generate Recommendations", systemImage: "lightbulb")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(problemDescription.isEmpty || recommender.isGenerating)
                
                // Current recommendations
                if let recommendations = recommender.currentRecommendations {
                    RecommendationsDisplayView(
                        recommendations: recommendations,
                        onViewDetails: { showingDetailedView = true }
                    )
                }
                
                // Comparison matrix
                if !recommender.comparisonMatrix.isEmpty {
                    ComparisonMatrixView(matrix: recommender.comparisonMatrix)
                }
                
                // Implementation guide
                if let guide = recommender.implementationGuide {
                    ImplementationGuideView(guide: guide)
                }
                
                // History
                if !recommender.recommendationHistory.isEmpty {
                    RecommendationHistoryView(
                        history: recommender.recommendationHistory,
                        onSelect: { recommendations in
                            recommender.currentRecommendations = recommendations
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Reasoning Recommender")
        .sheet(isPresented: $showingDetailedView) {
            if let recommendations = recommender.currentRecommendations {
                DetailedRecommendationsView(recommendations: recommendations)
            }
        }
    }
    
    private func generateRecommendations() {
        Task {
            await recommender.generateRecommendations(
                for: problemDescription,
                context: context,
                type: recommendationType,
                constraints: Array(constraints)
            )
        }
    }
    
    private func loadExampleProblem() {
        problemDescription = "Optimize delivery routes for a fleet of 50 vehicles serving 500 customers daily"
        context = "E-commerce company with same-day delivery promise, operating in a metropolitan area with dynamic traffic conditions"
        constraints = [.timeLimit, .scalability, .realTime]
    }
}

// MARK: - Reasoning Recommender Engine

class ReasoningRecommender: ObservableObject {
    @Published var currentRecommendations: RecommendationSet?
    @Published var comparisonMatrix: [ComparisonItem] = []
    @Published var implementationGuide: ImplementationGuide?
    @Published var recommendationHistory: [RecommendationSet] = []
    @Published var isGenerating = false
    @Published var constraints: [ReasoningRecommenderView.Constraint] = []
    @Published var recommendationType: ReasoningRecommenderView.RecommendationType = .approach
    
    private let client: DeepSeekClient
    
    init() {
        self.client = DeepSeekClient(apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "")
    }
    
    func generateRecommendations(for problem: String, context: String, type: ReasoningRecommenderView.RecommendationType, constraints: [ReasoningRecommenderView.Constraint]) async {
        await MainActor.run { isGenerating = true }
        
        do {
            let messages: [Message] = [
                Message(role: .system, content: """
                    You are an expert in reasoning methodologies and problem-solving approaches.
                    
                    Recommendation Type: \(type.rawValue) - \(type.description)
                    
                    Consider these constraints:
                    \(constraints.map { "- \($0.rawValue): \($0.impact)" }.joined(separator: "\n"))
                    
                    Provide:
                    1. Top 3-5 recommended approaches
                    2. Pros and cons for each
                    3. Suitability scores based on the problem
                    4. Implementation complexity
                    5. Success factors
                    6. Potential pitfalls
                    7. Comparison between approaches
                    8. Step-by-step implementation guide
                    """),
                Message(role: .user, content: """
                    Problem: \(problem)
                    
                    Context: \(context)
                    
                    Please recommend the best \(type.rawValue.lowercased()) for solving this problem.
                    """)
            ]
            
            let params = ChatCompletionParameters(
                model: "deepseek-reasoner",
                messages: messages,
                temperature: 0.3,
                maxTokens: 4000
            )
            
            let response = try await client.chatCompletion(params: params)
            
            if let content = response.choices.first?.message.content {
                let recommendations = parseRecommendations(
                    content,
                    problem: problem,
                    context: context,
                    type: type,
                    constraints: constraints
                )
                
                await MainActor.run {
                    self.currentRecommendations = recommendations
                    self.comparisonMatrix = generateComparisonMatrix(from: recommendations.recommendations)
                    self.implementationGuide = extractImplementationGuide(from: content, recommendations: recommendations)
                    self.recommendationHistory.append(recommendations)
                    self.isGenerating = false
                }
            }
        } catch {
            print("Error generating recommendations: \(error)")
            await MainActor.run { isGenerating = false }
        }
    }
    
    private func parseRecommendations(_ content: String, problem: String, context: String, type: ReasoningRecommenderView.RecommendationType, constraints: [ReasoningRecommenderView.Constraint]) -> RecommendationSet {
        let recommendations = extractRecommendations(from: content)
        let reasoning = extractReasoning(from: content)
        
        return RecommendationSet(
            id: UUID().uuidString,
            problem: problem,
            context: context,
            type: type,
            constraints: constraints,
            recommendations: recommendations,
            reasoning: reasoning,
            timestamp: Date()
        )
    }
    
    private func extractRecommendations(from content: String) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Look for numbered recommendations
        let pattern = #"(\d+)\.\s*([^:]+):(.+?)(?=\d+\.|Comparison:|Implementation:|$)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                if let nameRange = Range(match.range(at: 2), in: content),
                   let descRange = Range(match.range(at: 3), in: content) {
                    let name = String(content[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let description = String(content[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let recommendation = Recommendation(
                        name: name,
                        description: extractDescription(from: description),
                        pros: extractPros(from: description),
                        cons: extractCons(from: description),
                        suitabilityScore: extractScore(from: description),
                        complexity: extractComplexity(from: description),
                        successFactors: extractSuccessFactors(from: description),
                        pitfalls: extractPitfalls(from: description),
                        resources: extractResources(from: description)
                    )
                    recommendations.append(recommendation)
                }
            }
        }
        
        return recommendations
    }
    
    private func extractDescription(from text: String) -> String {
        // Extract the main description before pros/cons
        let lines = text.components(separatedBy: "\n")
        var descriptionLines: [String] = []
        
        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.contains("pros:") || lowercased.contains("cons:") ||
               lowercased.contains("suitability:") || lowercased.contains("complexity:") {
                break
            }
            if !line.isEmpty {
                descriptionLines.append(line)
            }
        }
        
        return descriptionLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractPros(from text: String) -> [String] {
        return extractListItems(from: text, section: "Pros")
    }
    
    private func extractCons(from text: String) -> [String] {
        return extractListItems(from: text, section: "Cons")
    }
    
    private func extractListItems(from text: String, section: String) -> [String] {
        var items: [String] = []
        
        if let sectionRange = text.range(of: "\(section):", options: .caseInsensitive) {
            let startIndex = sectionRange.upperBound
            let remainingText = String(text[startIndex...])
            
            // Find where the next section starts
            let endMarkers = ["Pros:", "Cons:", "Suitability:", "Complexity:", "Success Factors:", "Pitfalls:"]
            var endIndex = remainingText.endIndex
            
            for marker in endMarkers {
                if marker != "\(section):" {
                    if let markerRange = remainingText.range(of: marker, options: .caseInsensitive) {
                        endIndex = min(endIndex, markerRange.lowerBound)
                    }
                }
            }
            
            let sectionText = String(remainingText[..<endIndex])
            let lines = sectionText.components(separatedBy: "\n")
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && (trimmed.hasPrefix("-") || trimmed.hasPrefix("•")) {
                    items.append(trimmed.replacingOccurrences(of: "- ", with: "")
                        .replacingOccurrences(of: "• ", with: ""))
                }
            }
        }
        
        return items
    }
    
    private func extractScore(from text: String) -> Double {
        let pattern = #"[Ss]uitability.*?(\d+)/10|(\d+)%\s*suitable"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text),
                   let score = Double(text[range]) {
                    return score / 10.0
                } else if let range = Range(match.range(at: 2), in: text),
                          let score = Double(text[range]) {
                    return score / 100.0
                }
            }
        }
        
        return 0.7 // Default score
    }
    
    private func extractComplexity(from text: String) -> ComplexityLevel {
        let lowercased = text.lowercased()
        if lowercased.contains("very complex") || lowercased.contains("highly complex") {
            return .veryHigh
        } else if lowercased.contains("complex") || lowercased.contains("high complexity") {
            return .high
        } else if lowercased.contains("moderate") || lowercased.contains("medium") {
            return .medium
        } else if lowercased.contains("simple") || lowercased.contains("low complexity") {
            return .low
        } else {
            return .medium
        }
    }
    
    private func extractSuccessFactors(from text: String) -> [String] {
        return extractListItems(from: text, section: "Success Factors")
    }
    
    private func extractPitfalls(from text: String) -> [String] {
        return extractListItems(from: text, section: "Pitfalls")
    }
    
    private func extractResources(from text: String) -> [Resource] {
        var resources: [Resource] = []
        
        // Look for mentioned resources
        if text.lowercased().contains("algorithm") {
            resources.append(Resource(type: .algorithm, name: "Algorithm Implementation", description: "Core algorithmic approach"))
        }
        if text.lowercased().contains("framework") {
            resources.append(Resource(type: .framework, name: "Framework", description: "Structured approach"))
        }
        if text.lowercased().contains("tool") || text.lowercased().contains("library") {
            resources.append(Resource(type: .tool, name: "Tools & Libraries", description: "Supporting tools"))
        }
        if text.lowercased().contains("paper") || text.lowercased().contains("research") {
            resources.append(Resource(type: .paper, name: "Research Papers", description: "Academic references"))
        }
        
        return resources
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
    
    private func generateComparisonMatrix(from recommendations: [Recommendation]) -> [ComparisonItem] {
        var matrix: [ComparisonItem] = []
        
        let criteria = ["Suitability", "Complexity", "Time to Implement", "Scalability", "Accuracy"]
        
        for criterion in criteria {
            var scores: [String: Double] = [:]
            
            for recommendation in recommendations {
                switch criterion {
                case "Suitability":
                    scores[recommendation.name] = recommendation.suitabilityScore
                case "Complexity":
                    scores[recommendation.name] = complexityToScore(recommendation.complexity)
                case "Time to Implement":
                    scores[recommendation.name] = timeToImplementScore(recommendation.complexity)
                case "Scalability":
                    scores[recommendation.name] = scalabilityScore(from: recommendation)
                case "Accuracy":
                    scores[recommendation.name] = accuracyScore(from: recommendation)
                default:
                    scores[recommendation.name] = 0.5
                }
            }
            
            matrix.append(ComparisonItem(criterion: criterion, scores: scores))
        }
        
        return matrix
    }
    
    private func complexityToScore(_ complexity: ComplexityLevel) -> Double {
        switch complexity {
        case .low: return 0.9
        case .medium: return 0.7
        case .high: return 0.4
        case .veryHigh: return 0.2
        }
    }
    
    private func timeToImplementScore(_ complexity: ComplexityLevel) -> Double {
        switch complexity {
        case .low: return 0.9
        case .medium: return 0.6
        case .high: return 0.3
        case .veryHigh: return 0.1
        }
    }
    
    private func scalabilityScore(from recommendation: Recommendation) -> Double {
        // Check if scalability is mentioned in pros/cons
        let allText = (recommendation.pros + recommendation.cons).joined(separator: " ").lowercased()
        if allText.contains("scalable") || allText.contains("scales well") {
            return 0.8
        } else if allText.contains("limited scale") || allText.contains("doesn't scale") {
            return 0.3
        }
        return 0.6
    }
    
    private func accuracyScore(from recommendation: Recommendation) -> Double {
        // Check accuracy mentions
        let allText = recommendation.description.lowercased()
        if allText.contains("high accuracy") || allText.contains("precise") {
            return 0.9
        } else if allText.contains("accurate") {
            return 0.7
        } else if allText.contains("approximate") {
            return 0.5
        }
        return 0.6
    }
    
    private func extractImplementationGuide(from content: String, recommendations: RecommendationSet) -> ImplementationGuide? {
        guard let firstRec = recommendations.recommendations.first else { return nil }
        
        let steps = extractImplementationSteps(from: content)
        let timeline = generateTimeline(for: firstRec.complexity)
        let requirements = extractRequirements(from: content)
        let milestones = generateMilestones(from: steps)
        
        return ImplementationGuide(
            recommendationName: firstRec.name,
            steps: steps,
            timeline: timeline,
            requirements: requirements,
            milestones: milestones
        )
    }
    
    private func extractImplementationSteps(from content: String) -> [ImplementationStep] {
        var steps: [ImplementationStep] = []
        
        if let section = extractSection("Implementation", from: content) {
            let stepPattern = #"Step (\d+):(.+?)(?=Step \d+:|$)"#
            if let regex = try? NSRegularExpression(pattern: stepPattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: section, range: NSRange(section.startIndex..., in: section))
                
                for match in matches {
                    if let numberRange = Range(match.range(at: 1), in: section),
                       let descRange = Range(match.range(at: 2), in: section) {
                        let number = Int(section[numberRange]) ?? 0
                        let description = String(section[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        steps.append(ImplementationStep(
                            number: number,
                            title: "Step \(number)",
                            description: description,
                            duration: estimateDuration(from: description),
                            dependencies: extractDependencies(from: description)
                        ))
                    }
                }
            }
        }
        
        return steps
    }
    
    private func extractSection(_ section: String, from content: String) -> String? {
        if let sectionRange = content.range(of: "\(section):", options: .caseInsensitive) {
            let startIndex = sectionRange.upperBound
            let remainingContent = String(content[startIndex...])
            return remainingContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func estimateDuration(from description: String) -> String {
        let lowercased = description.lowercased()
        if lowercased.contains("quick") || lowercased.contains("simple") {
            return "1-2 days"
        } else if lowercased.contains("complex") || lowercased.contains("detailed") {
            return "1-2 weeks"
        } else {
            return "3-5 days"
        }
    }
    
    private func extractDependencies(from description: String) -> [String] {
        var dependencies: [String] = []
        
        if description.lowercased().contains("requires") || description.lowercased().contains("depends on") {
            // Extract what it depends on
            dependencies.append("Previous steps")
        }
        
        return dependencies
    }
    
    private func generateTimeline(for complexity: ComplexityLevel) -> String {
        switch complexity {
        case .low: return "1-2 weeks"
        case .medium: return "3-4 weeks"
        case .high: return "1-2 months"
        case .veryHigh: return "2-3 months"
        }
    }
    
    private func extractRequirements(from content: String) -> [String] {
        var requirements: [String] = []
        
        if let section = extractSection("Requirements", from: content) {
            let lines = section.components(separatedBy: "\n").filter { !$0.isEmpty }
            requirements = lines.map { $0.replacingOccurrences(of: "- ", with: "")
                .replacingOccurrences(of: "• ", with: "") }
        }
        
        // Add default requirements based on content
        if content.lowercased().contains("data") {
            requirements.append("Data collection and preparation")
        }
        if content.lowercased().contains("team") {
            requirements.append("Team coordination and training")
        }
        if content.lowercased().contains("infrastructure") {
            requirements.append("Infrastructure setup")
        }
        
        return requirements
    }
    
    private func generateMilestones(from steps: [ImplementationStep]) -> [Milestone] {
        var milestones: [Milestone] = []
        
        // Create milestones at key points
        if steps.count >= 3 {
            milestones.append(Milestone(
                name: "Foundation Complete",
                description: "Basic setup and infrastructure ready",
                targetWeek: 1
            ))
        }
        
        if steps.count >= 6 {
            milestones.append(Milestone(
                name: "Core Implementation",
                description: "Main functionality implemented",
                targetWeek: 3
            ))
        }
        
        milestones.append(Milestone(
            name: "Full Deployment",
            description: "Complete solution deployed and tested",
            targetWeek: steps.count > 5 ? 6 : 3
        ))
        
        return milestones
    }
}

// MARK: - Data Models

struct RecommendationSet: Identifiable {
    let id: String
    let problem: String
    let context: String
    let type: ReasoningRecommenderView.RecommendationType
    let constraints: [ReasoningRecommenderView.Constraint]
    let recommendations: [Recommendation]
    let reasoning: String
    let timestamp: Date
}

struct Recommendation: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let pros: [String]
    let cons: [String]
    let suitabilityScore: Double
    let complexity: ComplexityLevel
    let successFactors: [String]
    let pitfalls: [String]
    let resources: [Resource]
}

enum ComplexityLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case veryHigh = "Very High"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}

struct Resource: Identifiable {
    let id = UUID()
    let type: ResourceType
    let name: String
    let description: String
}

enum ResourceType {
    case algorithm
    case framework
    case tool
    case paper
    case tutorial
    
    var icon: String {
        switch self {
        case .algorithm: return "function"
        case .framework: return "square.stack.3d.up"
        case .tool: return "wrench"
        case .paper: return "doc.text"
        case .tutorial: return "book"
        }
    }
}

struct ComparisonItem {
    let criterion: String
    let scores: [String: Double]
}

struct ImplementationGuide {
    let recommendationName: String
    let steps: [ImplementationStep]
    let timeline: String
    let requirements: [String]
    let milestones: [Milestone]
}

struct ImplementationStep: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
    let description: String
    let duration: String
    let dependencies: [String]
}

struct Milestone: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let targetWeek: Int
}

// MARK: - Supporting Views

struct ProblemInputSection: View {
    @Binding var problem: String
    @Binding var context: String
    let onLoadExample: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Problem Description", systemImage: "questionmark.circle")
                    .font(.headline)
                
                Spacer()
                
                Button("Load Example", action: onLoadExample)
                    .font(.caption)
            }
            
            TextEditor(text: $problem)
                .frame(height: 80)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Label("Context & Requirements", systemImage: "info.circle")
                .font(.headline)
            
            TextEditor(text: $context)
                .frame(height: 60)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct ConstraintsSelectionView: View {
    @Binding var selectedConstraints: Set<ReasoningRecommenderView.Constraint>
    let onChange: (Set<ReasoningRecommenderView.Constraint>) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Constraints & Requirements")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 8) {
                ForEach(ReasoningRecommenderView.Constraint.allCases, id: \.self) { constraint in
                    ConstraintToggle(
                        constraint: constraint,
                        isSelected: selectedConstraints.contains(constraint),
                        action: {
                            if selectedConstraints.contains(constraint) {
                                selectedConstraints.remove(constraint)
                            } else {
                                selectedConstraints.insert(constraint)
                            }
                            onChange(selectedConstraints)
                        }
                    )
                }
            }
        }
    }
}

struct ConstraintToggle: View {
    let constraint: ReasoningRecommenderView.Constraint
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: constraint.icon)
                        .foregroundColor(isSelected ? .white : .blue)
                    Text(constraint.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(constraint.impact)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationTypeView: View {
    @Binding var selectedType: ReasoningRecommenderView.RecommendationType
    let onChange: (ReasoningRecommenderView.RecommendationType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendation Type")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ReasoningRecommenderView.RecommendationType.allCases, id: \.self) { type in
                        TypeCard(
                            type: type,
                            isSelected: selectedType == type,
                            action: {
                                selectedType = type
                                onChange(type)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct TypeCard: View {
    let type: ReasoningRecommenderView.RecommendationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(type.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationsDisplayView: View {
    let recommendations: RecommendationSet
    let onViewDetails: () -> Void
    @State private var selectedRecommendation: Recommendation?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Recommendations", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                Spacer()
                
                Button("View Details", action: onViewDetails)
                    .font(.caption)
            }
            
            ForEach(recommendations.recommendations) { recommendation in
                RecommendationCard(
                    recommendation: recommendation,
                    isExpanded: selectedRecommendation?.id == recommendation.id,
                    onTap: {
                        withAnimation {
                            if selectedRecommendation?.id == recommendation.id {
                                selectedRecommendation = nil
                            } else {
                                selectedRecommendation = recommendation
                            }
                        }
                    }
                )
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.name)
                            .font(.headline)
                        
                        HStack {
                            // Suitability score
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text("\(Int(recommendation.suitabilityScore * 100))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            // Complexity
                            Text(recommendation.complexity.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(recommendation.complexity.color.opacity(0.2))
                                .foregroundColor(recommendation.complexity.color)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(recommendation.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            if isExpanded {
                // Pros and Cons
                HStack(alignment: .top, spacing: 16) {
                    // Pros
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Pros", systemImage: "plus.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        
                        ForEach(recommendation.pros, id: \.self) { pro in
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundColor(.green)
                                Text(pro)
                                    .font(.caption)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    
                    // Cons
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Cons", systemImage: "minus.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        
                        ForEach(recommendation.cons, id: \.self) { con in
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundColor(.red)
                                Text(con)
                                    .font(.caption)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                
                // Success Factors
                if !recommendation.successFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Success Factors", systemImage: "checkmark.seal")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        ForEach(recommendation.successFactors, id: \.self) { factor in
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(factor)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Resources
                if !recommendation.resources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Resources", systemImage: "folder")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        ForEach(recommendation.resources) { resource in
                            HStack {
                                Image(systemName: resource.type.icon)
                                    .foregroundColor(.purple)
                                    .font(.caption)
                                Text(resource.name)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ComparisonMatrixView: View {
    let matrix: [ComparisonItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparison Matrix")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(matrix, id: \.criterion) { item in
                    ComparisonRow(item: item)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

struct ComparisonRow: View {
    let item: ComparisonItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.criterion)
                .font(.caption)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                ForEach(Array(item.scores.sorted(by: { $0.value > $1.value })), id: \.key) { name, score in
                    VStack(spacing: 2) {
                        Text(name.prefix(10))
                            .font(.caption2)
                            .lineLimit(1)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 40)
                            
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorForScore(score))
                                    .frame(height: geometry.size.height * score)
                                    .offset(y: geometry.size.height * (1 - score))
                            }
                        }
                        .frame(height: 40)
                        
                        Text("\(Int(score * 100))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        else if score >= 0.6 { return .blue }
        else if score >= 0.4 { return .orange }
        else { return .red }
    }
}

struct ImplementationGuideView: View {
    let guide: ImplementationGuide
    @State private var expandedSteps: Set<UUID> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Implementation Guide", systemImage: "list.bullet.clipboard")
                    .font(.headline)
                
                Spacer()
                
                Label(guide.timeline, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Requirements
            if !guide.requirements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Requirements")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(guide.requirements, id: \.self) { requirement in
                        HStack(alignment: .top) {
                            Image(systemName: "checkmark.square")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(requirement)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Steps
            VStack(alignment: .leading, spacing: 8) {
                Text("Implementation Steps")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(guide.steps) { step in
                    StepView(
                        step: step,
                        isExpanded: expandedSteps.contains(step.id),
                        onToggle: {
                            if expandedSteps.contains(step.id) {
                                expandedSteps.remove(step.id)
                            } else {
                                expandedSteps.insert(step.id)
                            }
                        }
                    )
                }
            }
            
            // Milestones
            if !guide.milestones.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Milestones")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(guide.milestones) { milestone in
                        HStack {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(milestone.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(milestone.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("Week \(milestone.targetWeek)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
}

struct StepView: View {
    let step: ImplementationStep
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(step.number)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(step.duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.description)
                        .font(.caption)
                        .padding(.leading, 32)
                    
                    if !step.dependencies.isEmpty {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Dependencies: \(step.dependencies.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 32)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct DetailedRecommendationsView: View {
    let recommendations: RecommendationSet
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Problem context
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Problem", systemImage: "questionmark.circle")
                            .font(.headline)
                        Text(recommendations.problem)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        
                        if !recommendations.context.isEmpty {
                            Label("Context", systemImage: "info.circle")
                                .font(.headline)
                            Text(recommendations.context)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Constraints
                    if !recommendations.constraints.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Constraints", systemImage: "lock")
                                .font(.headline)
                            
                            ForEach(recommendations.constraints, id: \.self) { constraint in
                                HStack {
                                    Image(systemName: constraint.icon)
                                        .foregroundColor(.orange)
                                    Text(constraint.rawValue)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    
                    // Full recommendations
                    VStack(alignment: .leading, spacing: 16) {
                        Label("All Recommendations", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundColor(.yellow)
                        
                        ForEach(recommendations.recommendations) { recommendation in
                            DetailedRecommendationView(recommendation: recommendation)
                        }
                    }
                    
                    // Reasoning
                    if !recommendations.reasoning.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI Reasoning", systemImage: "brain")
                                .font(.headline)
                            
                            ScrollView {
                                Text(recommendations.reasoning)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding()
                            }
                            .frame(maxHeight: 200)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Detailed Recommendations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailedRecommendationView: View {
    let recommendation: Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recommendation.name)
                .font(.headline)
            
            Text(recommendation.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // All details expanded
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Pros", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    ForEach(recommendation.pros, id: \.self) { pro in
                        Text("• \(pro)")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Cons", systemImage: "minus.circle.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    ForEach(recommendation.cons, id: \.self) { con in
                        Text("• \(con)")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            if !recommendation.pitfalls.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Potential Pitfalls", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    ForEach(recommendation.pitfalls, id: \.self) { pitfall in
                        Text("• \(pitfall)")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RecommendationHistoryView: View {
    let history: [RecommendationSet]
    let onSelect: (RecommendationSet) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline)
            
            ForEach(history.reversed()) { recommendations in
                Button(action: { onSelect(recommendations) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendations.problem)
                                .lineLimit(1)
                                .font(.subheadline)
                            
                            HStack {
                                Label(recommendations.type.rawValue, systemImage: recommendations.type.icon)
                                    .font(.caption)
                                
                                Text("• \(recommendations.recommendations.count) options")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(recommendations.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
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

struct ReasoningRecommenderApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ReasoningRecommenderView()
            }
        }
    }
}