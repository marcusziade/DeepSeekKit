import SwiftUI
import DeepSeekKit

// Create reasoning explanations
struct ReasoningExplainerView: View {
    @StateObject private var explainer = ReasoningExplainer()
    @State private var reasoningInput = ""
    @State private var audienceLevel: AudienceLevel = .general
    @State private var explanationStyle: ExplanationStyle = .narrative
    @State private var includeVisuals = true
    @State private var showingShareSheet = false
    
    enum AudienceLevel: String, CaseIterable {
        case child = "Child (8-12)"
        case teen = "Teen (13-17)"
        case general = "General"
        case technical = "Technical"
        case expert = "Expert"
        
        var description: String {
            switch self {
            case .child: return "Simple language, fun examples"
            case .teen: return "Clear explanations, relatable examples"
            case .general: return "Accessible to most adults"
            case .technical: return "Includes technical details"
            case .expert: return "Assumes domain knowledge"
            }
        }
        
        var icon: String {
            switch self {
            case .child: return "face.smiling"
            case .teen: return "studentdesk"
            case .general: return "person.2"
            case .technical: return "gearshape"
            case .expert: return "graduationcap"
            }
        }
    }
    
    enum ExplanationStyle: String, CaseIterable {
        case narrative = "Narrative"
        case stepByStep = "Step-by-Step"
        case visual = "Visual"
        case analogy = "Analogy-Based"
        case socratic = "Socratic"
        
        var description: String {
            switch self {
            case .narrative: return "Tell a story"
            case .stepByStep: return "Numbered steps"
            case .visual: return "Diagrams and charts"
            case .analogy: return "Use comparisons"
            case .socratic: return "Ask questions"
            }
        }
        
        var icon: String {
            switch self {
            case .narrative: return "book"
            case .stepByStep: return "list.number"
            case .visual: return "chart.pie"
            case .analogy: return "arrow.triangle.2.circlepath"
            case .socratic: return "questionmark.bubble"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Input section
                ExplanationInputSection(
                    reasoning: $reasoningInput,
                    onLoadExample: loadExampleReasoning
                )
                
                // Audience selection
                AudienceSelectionView(
                    selectedLevel: $audienceLevel,
                    onChange: { explainer.targetAudience = $0 }
                )
                
                // Style selection
                StyleSelectionView(
                    selectedStyle: $explanationStyle,
                    includeVisuals: $includeVisuals,
                    onChange: { style, visuals in
                        explainer.explanationStyle = style
                        explainer.includeVisualElements = visuals
                    }
                )
                
                // Generate button
                Button(action: generateExplanation) {
                    if explainer.isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Label("Generate Explanation", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(reasoningInput.isEmpty || explainer.isGenerating)
                
                // Current explanation
                if let explanation = explainer.currentExplanation {
                    ExplanationDisplayView(
                        explanation: explanation,
                        onShare: { showingShareSheet = true }
                    )
                }
                
                // Related concepts
                if !explainer.relatedConcepts.isEmpty {
                    RelatedConceptsView(concepts: explainer.relatedConcepts)
                }
                
                // History
                if !explainer.explanationHistory.isEmpty {
                    ExplanationHistoryView(
                        history: explainer.explanationHistory,
                        onSelect: { explanation in
                            explainer.currentExplanation = explanation
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Reasoning Explainer")
        .sheet(isPresented: $showingShareSheet) {
            if let explanation = explainer.currentExplanation {
                ShareSheet(items: [explanation.formattedExplanation])
            }
        }
    }
    
    private func generateExplanation() {
        Task {
            await explainer.generateExplanation(
                for: reasoningInput,
                audience: audienceLevel,
                style: explanationStyle
            )
        }
    }
    
    private func loadExampleReasoning() {
        reasoningInput = """
        To find the shortest path in a graph using Dijkstra's algorithm:
        
        1. Initialize distances: Set distance to source as 0, all others as infinity
        2. Create a priority queue with all vertices
        3. While queue is not empty:
           - Extract vertex with minimum distance
           - For each neighbor:
             - Calculate tentative distance through current vertex
             - If shorter than known distance, update it
        4. Return the distance array
        
        This works because we always process the closest unvisited vertex, guaranteeing optimal paths.
        """
    }
}

// MARK: - Reasoning Explainer Engine

class ReasoningExplainer: ObservableObject {
    @Published var currentExplanation: Explanation?
    @Published var relatedConcepts: [RelatedConcept] = []
    @Published var explanationHistory: [Explanation] = []
    @Published var isGenerating = false
    @Published var targetAudience: ReasoningExplainerView.AudienceLevel = .general
    @Published var explanationStyle: ReasoningExplainerView.ExplanationStyle = .narrative
    @Published var includeVisualElements = true
    
    private let client: DeepSeekClient
    
    init() {
        self.client = DeepSeekClient(apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "")
    }
    
    func generateExplanation(for reasoning: String, audience: ReasoningExplainerView.AudienceLevel, style: ReasoningExplainerView.ExplanationStyle) async {
        await MainActor.run { isGenerating = true }
        
        do {
            let messages: [Message] = [
                Message(role: .system, content: """
                    You are an expert at explaining complex reasoning in simple, engaging ways.
                    
                    Target Audience: \(audience.rawValue) - \(audience.description)
                    Explanation Style: \(style.rawValue) - \(style.description)
                    
                    Create an explanation that:
                    1. Matches the audience's understanding level
                    2. Uses the requested style effectively
                    3. Includes concrete examples
                    4. Highlights key insights
                    5. Makes the reasoning memorable
                    
                    \(includeVisualElements ? "Include descriptions of visual elements that would help explain the concept." : "")
                    """),
                Message(role: .user, content: "Explain this reasoning:\n\n\(reasoning)")
            ]
            
            let params = ChatCompletionParameters(
                model: "deepseek-reasoner",
                messages: messages,
                temperature: 0.7,
                maxTokens: 3000
            )
            
            let response = try await client.chatCompletion(params: params)
            
            if let content = response.choices.first?.message.content {
                let explanation = parseExplanation(
                    content,
                    originalReasoning: reasoning,
                    audience: audience,
                    style: style
                )
                
                await MainActor.run {
                    self.currentExplanation = explanation
                    self.relatedConcepts = extractRelatedConcepts(from: content)
                    self.explanationHistory.append(explanation)
                    self.isGenerating = false
                }
            }
        } catch {
            print("Error generating explanation: \(error)")
            await MainActor.run { isGenerating = false }
        }
    }
    
    private func parseExplanation(_ content: String, originalReasoning: String, audience: ReasoningExplainerView.AudienceLevel, style: ReasoningExplainerView.ExplanationStyle) -> Explanation {
        let mainExplanation = extractMainExplanation(from: content)
        let keyPoints = extractKeyPoints(from: content)
        let examples = extractExamples(from: content)
        let visualElements = includeVisualElements ? extractVisualElements(from: content) : []
        let summary = extractSummary(from: content)
        let questions = style == .socratic ? extractQuestions(from: content) : []
        
        return Explanation(
            id: UUID().uuidString,
            originalReasoning: originalReasoning,
            audience: audience,
            style: style,
            mainExplanation: mainExplanation,
            keyPoints: keyPoints,
            examples: examples,
            visualElements: visualElements,
            summary: summary,
            questions: questions,
            timestamp: Date()
        )
    }
    
    private func extractMainExplanation(from content: String) -> String {
        // Extract the main body of the explanation
        let lines = content.components(separatedBy: "\n")
        var explanationLines: [String] = []
        var inMainSection = true
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Stop at section headers
            if trimmed.hasPrefix("Key Points:") ||
               trimmed.hasPrefix("Examples:") ||
               trimmed.hasPrefix("Visual:") ||
               trimmed.hasPrefix("Summary:") ||
               trimmed.hasPrefix("Questions:") {
                inMainSection = false
            }
            
            if inMainSection && !trimmed.isEmpty {
                explanationLines.append(line)
            }
        }
        
        return explanationLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractKeyPoints(from content: String) -> [KeyPoint] {
        var keyPoints: [KeyPoint] = []
        
        if let section = extractSection("Key Points", from: content) {
            let lines = section.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for line in lines {
                if line.contains("-") || line.contains("•") || line.contains(":") {
                    let point = line.replacingOccurrences(of: "- ", with: "")
                        .replacingOccurrences(of: "• ", with: "")
                    
                    let importance = determineImportance(from: line)
                    keyPoints.append(KeyPoint(
                        text: point,
                        importance: importance,
                        icon: iconForKeyPoint(point)
                    ))
                }
            }
        }
        
        return keyPoints
    }
    
    private func determineImportance(from text: String) -> KeyPointImportance {
        let lowercased = text.lowercased()
        if lowercased.contains("critical") || lowercased.contains("essential") || lowercased.contains("most important") {
            return .critical
        } else if lowercased.contains("important") || lowercased.contains("key") {
            return .high
        } else if lowercased.contains("note") || lowercased.contains("remember") {
            return .medium
        } else {
            return .low
        }
    }
    
    private func iconForKeyPoint(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("step") || lowercased.contains("process") {
            return "arrow.right.circle"
        } else if lowercased.contains("result") || lowercased.contains("outcome") {
            return "checkmark.circle"
        } else if lowercased.contains("warning") || lowercased.contains("caution") {
            return "exclamationmark.triangle"
        } else if lowercased.contains("idea") || lowercased.contains("insight") {
            return "lightbulb"
        } else {
            return "info.circle"
        }
    }
    
    private func extractExamples(from content: String) -> [Example] {
        var examples: [Example] = []
        
        if let section = extractSection("Examples", from: content) {
            let blocks = section.components(separatedBy: "\n\n")
            
            for block in blocks {
                if !block.isEmpty {
                    let lines = block.components(separatedBy: "\n")
                    let title = lines.first ?? "Example"
                    let description = lines.dropFirst().joined(separator: "\n")
                    
                    examples.append(Example(
                        title: title.replacingOccurrences(of: "Example:", with: "").trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description,
                        code: extractCode(from: block),
                        visualization: extractVisualization(from: block)
                    ))
                }
            }
        }
        
        return examples
    }
    
    private func extractCode(from text: String) -> String? {
        if let codeStart = text.range(of: "```"),
           let codeEnd = text.range(of: "```", options: .backwards) {
            let code = String(text[codeStart.upperBound..<codeEnd.lowerBound])
            return code.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func extractVisualization(from text: String) -> String? {
        if text.lowercased().contains("diagram:") || text.lowercased().contains("visual:") {
            return "Chart visualization placeholder"
        }
        return nil
    }
    
    private func extractVisualElements(from content: String) -> [VisualElement] {
        var elements: [VisualElement] = []
        
        if let section = extractSection("Visual", from: content) {
            let descriptions = section.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for description in descriptions {
                let type = determineVisualType(from: description)
                elements.append(VisualElement(
                    type: type,
                    description: description,
                    data: generateVisualData(for: type)
                ))
            }
        }
        
        return elements
    }
    
    private func determineVisualType(from description: String) -> VisualType {
        let lowercased = description.lowercased()
        if lowercased.contains("flow") || lowercased.contains("process") {
            return .flowChart
        } else if lowercased.contains("graph") || lowercased.contains("chart") {
            return .graph
        } else if lowercased.contains("diagram") {
            return .diagram
        } else if lowercased.contains("timeline") {
            return .timeline
        } else {
            return .illustration
        }
    }
    
    private func generateVisualData(for type: VisualType) -> [String: Any] {
        // Generate placeholder data for visual elements
        switch type {
        case .flowChart:
            return ["nodes": 5, "connections": 4]
        case .graph:
            return ["points": 10, "type": "line"]
        case .diagram:
            return ["components": 3]
        case .timeline:
            return ["events": 6]
        case .illustration:
            return ["elements": 4]
        }
    }
    
    private func extractSummary(from content: String) -> String {
        if let section = extractSection("Summary", from: content) {
            return section
        }
        
        // Fallback: look for concluding paragraphs
        let lines = content.components(separatedBy: "\n")
        for line in lines.reversed() {
            if line.lowercased().contains("in summary") ||
               line.lowercased().contains("to summarize") ||
               line.lowercased().contains("in conclusion") {
                return line
            }
        }
        
        return ""
    }
    
    private func extractQuestions(from content: String) -> [String] {
        var questions: [String] = []
        
        if let section = extractSection("Questions", from: content) {
            let lines = section.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for line in lines {
                if line.contains("?") {
                    questions.append(line.replacingOccurrences(of: "- ", with: "")
                        .replacingOccurrences(of: "• ", with: ""))
                }
            }
        }
        
        return questions
    }
    
    private func extractSection(_ section: String, from content: String) -> String? {
        if let sectionRange = content.range(of: "\(section):", options: .caseInsensitive) {
            let startIndex = sectionRange.upperBound
            let remainingContent = String(content[startIndex...])
            
            // Find next section
            let sections = ["Key Points", "Examples", "Visual", "Summary", "Questions"]
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
    
    private func extractRelatedConcepts(from content: String) -> [RelatedConcept] {
        var concepts: [RelatedConcept] = []
        
        // Look for mentioned concepts
        let conceptKeywords = [
            "algorithm", "method", "technique", "principle", "theory",
            "pattern", "approach", "strategy", "concept", "framework"
        ]
        
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        var foundConcepts = Set<String>()
        
        for (index, word) in words.enumerated() {
            for keyword in conceptKeywords {
                if word.lowercased().contains(keyword) && index > 0 {
                    let conceptName = words[index - 1] + " " + word
                    if !foundConcepts.contains(conceptName) {
                        foundConcepts.insert(conceptName)
                        concepts.append(RelatedConcept(
                            name: conceptName.capitalized,
                            relevance: 0.7 + Double.random(in: 0...0.3),
                            description: "Related \(keyword) that connects to this reasoning"
                        ))
                    }
                }
            }
        }
        
        return Array(concepts.prefix(5))
    }
}

// MARK: - Data Models

struct Explanation: Identifiable {
    let id: String
    let originalReasoning: String
    let audience: ReasoningExplainerView.AudienceLevel
    let style: ReasoningExplainerView.ExplanationStyle
    let mainExplanation: String
    let keyPoints: [KeyPoint]
    let examples: [Example]
    let visualElements: [VisualElement]
    let summary: String
    let questions: [String]
    let timestamp: Date
    
    var formattedExplanation: String {
        var result = mainExplanation + "\n\n"
        
        if !keyPoints.isEmpty {
            result += "Key Points:\n"
            result += keyPoints.map { "• \($0.text)" }.joined(separator: "\n")
            result += "\n\n"
        }
        
        if !examples.isEmpty {
            result += "Examples:\n"
            result += examples.map { "\($0.title): \($0.description)" }.joined(separator: "\n\n")
            result += "\n\n"
        }
        
        if !summary.isEmpty {
            result += "Summary: \(summary)\n"
        }
        
        return result
    }
}

struct KeyPoint: Identifiable {
    let id = UUID()
    let text: String
    let importance: KeyPointImportance
    let icon: String
}

enum KeyPointImportance {
    case critical
    case high
    case medium
    case low
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

struct Example: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let code: String?
    let visualization: String?
}

struct VisualElement: Identifiable {
    let id = UUID()
    let type: VisualType
    let description: String
    let data: [String: Any]
}

enum VisualType {
    case flowChart
    case graph
    case diagram
    case timeline
    case illustration
    
    var icon: String {
        switch self {
        case .flowChart: return "arrow.triangle.branch"
        case .graph: return "chart.line.uptrend.xyaxis"
        case .diagram: return "square.and.pencil"
        case .timeline: return "timeline.selection"
        case .illustration: return "photo"
        }
    }
}

struct RelatedConcept: Identifiable {
    let id = UUID()
    let name: String
    let relevance: Double
    let description: String
}

// MARK: - Supporting Views

struct ExplanationInputSection: View {
    @Binding var reasoning: String
    let onLoadExample: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Reasoning to Explain", systemImage: "text.quote")
                    .font(.headline)
                
                Spacer()
                
                Button("Load Example", action: onLoadExample)
                    .font(.caption)
            }
            
            TextEditor(text: $reasoning)
                .frame(height: 120)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Text("\(reasoning.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct AudienceSelectionView: View {
    @Binding var selectedLevel: ReasoningExplainerView.AudienceLevel
    let onChange: (ReasoningExplainerView.AudienceLevel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Audience")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ReasoningExplainerView.AudienceLevel.allCases, id: \.self) { level in
                        AudienceCard(
                            level: level,
                            isSelected: selectedLevel == level,
                            action: {
                                selectedLevel = level
                                onChange(level)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct AudienceCard: View {
    let level: ReasoningExplainerView.AudienceLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: level.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(level.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(level.description)
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

struct StyleSelectionView: View {
    @Binding var selectedStyle: ReasoningExplainerView.ExplanationStyle
    @Binding var includeVisuals: Bool
    let onChange: (ReasoningExplainerView.ExplanationStyle, Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explanation Style")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                ForEach(ReasoningExplainerView.ExplanationStyle.allCases, id: \.self) { style in
                    StyleOption(
                        style: style,
                        isSelected: selectedStyle == style,
                        action: {
                            selectedStyle = style
                            onChange(style, includeVisuals)
                        }
                    )
                }
            }
            
            Toggle("Include Visual Elements", isOn: $includeVisuals)
                .onChange(of: includeVisuals) { _ in
                    onChange(selectedStyle, includeVisuals)
                }
        }
    }
}

struct StyleOption: View {
    let style: ReasoningExplainerView.ExplanationStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: style.icon)
                    .foregroundColor(isSelected ? .white : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(style.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExplanationDisplayView: View {
    let explanation: Explanation
    let onShare: () -> Void
    @State private var expandedSections: Set<String> = ["main"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Label("Generated Explanation", systemImage: "doc.text.fill")
                        .font(.headline)
                    
                    HStack {
                        Label(explanation.audience.rawValue, systemImage: explanation.audience.icon)
                        Text("•")
                        Label(explanation.style.rawValue, systemImage: explanation.style.icon)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            
            // Main explanation
            ExpandableSection(
                title: "Explanation",
                isExpanded: expandedSections.contains("main"),
                onToggle: { toggleSection("main") }
            ) {
                Text(explanation.mainExplanation)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // Key points
            if !explanation.keyPoints.isEmpty {
                ExpandableSection(
                    title: "Key Points",
                    isExpanded: expandedSections.contains("keypoints"),
                    onToggle: { toggleSection("keypoints") }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(explanation.keyPoints) { point in
                            KeyPointView(point: point)
                        }
                    }
                }
            }
            
            // Examples
            if !explanation.examples.isEmpty {
                ExpandableSection(
                    title: "Examples",
                    isExpanded: expandedSections.contains("examples"),
                    onToggle: { toggleSection("examples") }
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(explanation.examples) { example in
                            ExampleView(example: example)
                        }
                    }
                }
            }
            
            // Visual elements
            if !explanation.visualElements.isEmpty {
                ExpandableSection(
                    title: "Visual Elements",
                    isExpanded: expandedSections.contains("visuals"),
                    onToggle: { toggleSection("visuals") }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(explanation.visualElements) { element in
                            VisualElementView(element: element)
                        }
                    }
                }
            }
            
            // Questions (for Socratic style)
            if !explanation.questions.isEmpty {
                ExpandableSection(
                    title: "Questions to Consider",
                    isExpanded: expandedSections.contains("questions"),
                    onToggle: { toggleSection("questions") }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(explanation.questions, id: \.self) { question in
                            HStack(alignment: .top) {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.blue)
                                Text(question)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            
            // Summary
            if !explanation.summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Summary", systemImage: "text.justify")
                        .font(.headline)
                    
                    Text(explanation.summary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }
}

struct ExpandableSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                content()
            }
        }
    }
}

struct KeyPointView: View {
    let point: KeyPoint
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: point.icon)
                .foregroundColor(point.importance.color)
                .font(.title3)
            
            Text(point.text)
                .font(.subheadline)
            
            Spacer()
            
            if point.importance == .critical {
                Text("Critical")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(point.importance.color.opacity(0.2))
                    .foregroundColor(point.importance.color)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(point.importance.color.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ExampleView: View {
    let example: Example
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Label(example.title, systemImage: "doc.text")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(example.description)
                    .font(.caption)
                    .padding(.leading, 24)
                
                if let code = example.code {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.leading, 24)
                }
                
                if let visualization = example.visualization {
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.blue)
                        Text(visualization)
                            .font(.caption)
                            .italic()
                    }
                    .padding(.leading, 24)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct VisualElementView: View {
    let element: VisualElement
    
    var body: some View {
        HStack {
            Image(systemName: element.type.icon)
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(element.description)
                    .font(.subheadline)
                
                // Placeholder for actual visual
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 100)
                    .overlay(
                        Text("Visual: \(element.type)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct RelatedConceptsView: View {
    let concepts: [RelatedConcept]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Concepts")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(concepts) { concept in
                        ConceptCard(concept: concept)
                    }
                }
            }
        }
    }
}

struct ConceptCard: View {
    let concept: RelatedConcept
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(concept.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(concept.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("Relevance")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                ProgressView(value: concept.relevance)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 60)
                
                Text("\(Int(concept.relevance * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 200)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ExplanationHistoryView: View {
    let history: [Explanation]
    let onSelect: (Explanation) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Explanation History")
                .font(.headline)
            
            ForEach(history.reversed()) { explanation in
                Button(action: { onSelect(explanation) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(explanation.originalReasoning)
                                .lineLimit(2)
                                .font(.subheadline)
                            
                            HStack {
                                Label(explanation.audience.rawValue, systemImage: explanation.audience.icon)
                                Text("•")
                                Label(explanation.style.rawValue, systemImage: explanation.style.icon)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(explanation.timestamp, style: .relative)
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - App

struct ReasoningExplainerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ReasoningExplainerView()
            }
        }
    }
}