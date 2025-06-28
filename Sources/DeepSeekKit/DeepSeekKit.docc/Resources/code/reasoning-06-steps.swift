import SwiftUI
import DeepSeekKit

// Extract reasoning steps
struct ReasoningStepsExtractor: View {
    @StateObject private var extractor = StepsExtractor()
    @State private var inputText = ""
    @State private var extractionMode: ExtractionMode = .automatic
    @State private var showingVisualization = false
    
    enum ExtractionMode: String, CaseIterable {
        case automatic = "Automatic"
        case structured = "Structured"
        case custom = "Custom Rules"
        
        var description: String {
            switch self {
            case .automatic:
                return "AI-powered step detection"
            case .structured:
                return "Pattern-based extraction"
            case .custom:
                return "User-defined rules"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Input section
                InputSection(
                    inputText: $inputText,
                    placeholder: "Enter reasoning text or paste AI response..."
                )
                
                // Mode selector
                ModeSelector(
                    selectedMode: $extractionMode,
                    onChange: { extractor.mode = $0 }
                )
                
                // Extraction controls
                ExtractionControls(
                    onExtract: performExtraction,
                    onVisualize: { showingVisualization = true },
                    isProcessing: extractor.isProcessing,
                    hasResults: !extractor.extractedSteps.isEmpty
                )
                
                // Results
                if !extractor.extractedSteps.isEmpty {
                    ExtractedStepsView(
                        steps: extractor.extractedSteps,
                        metadata: extractor.metadata
                    )
                }
                
                // Pattern library
                if extractionMode == .structured {
                    PatternLibrarySection(
                        patterns: extractor.availablePatterns,
                        selectedPatterns: extractor.selectedPatterns,
                        onTogglePattern: { pattern in
                            extractor.togglePattern(pattern)
                        }
                    )
                }
                
                // Custom rules editor
                if extractionMode == .custom {
                    CustomRulesEditor(
                        rules: extractor.customRules,
                        onAddRule: { rule in
                            extractor.addCustomRule(rule)
                        },
                        onRemoveRule: { rule in
                            extractor.removeCustomRule(rule)
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Reasoning Steps")
        .sheet(isPresented: $showingVisualization) {
            StepsVisualizationView(steps: extractor.extractedSteps)
        }
    }
    
    private func performExtraction() {
        Task {
            await extractor.extractSteps(from: inputText)
        }
    }
}

// MARK: - Steps Extractor Engine

class StepsExtractor: ObservableObject {
    @Published var extractedSteps: [ExtractedStep] = []
    @Published var metadata: ExtractionMetadata?
    @Published var isProcessing = false
    @Published var availablePatterns: [StepPattern] = []
    @Published var selectedPatterns: Set<String> = []
    @Published var customRules: [CustomRule] = []
    
    var mode: ReasoningStepsExtractor.ExtractionMode = .automatic
    
    private let client: DeepSeekClient
    
    // MARK: - Models
    
    struct ExtractedStep: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let content: String
        let type: StepType
        let subSteps: [SubStep]
        let dependencies: [Int] // Step numbers this step depends on
        let confidence: Double
        let keywords: [String]
        let position: TextPosition
        
        enum StepType {
            case initialization
            case calculation
            case verification
            case decision
            case conclusion
            case intermediate
            
            var color: Color {
                switch self {
                case .initialization: return .blue
                case .calculation: return .orange
                case .verification: return .green
                case .decision: return .purple
                case .conclusion: return .red
                case .intermediate: return .gray
                }
            }
            
            var icon: String {
                switch self {
                case .initialization: return "play.circle"
                case .calculation: return "number"
                case .verification: return "checkmark.shield"
                case .decision: return "arrow.triangle.branch"
                case .conclusion: return "flag.checkered"
                case .intermediate: return "arrow.right"
                }
            }
        }
        
        struct SubStep {
            let content: String
            let isOptional: Bool
        }
        
        struct TextPosition {
            let start: Int
            let end: Int
            let line: Int
        }
    }
    
    struct ExtractionMetadata {
        let totalSteps: Int
        let processingTime: TimeInterval
        let method: String
        let confidence: Double
        let textLength: Int
        let complexity: ComplexityLevel
        
        enum ComplexityLevel {
            case simple, moderate, complex
            
            var color: Color {
                switch self {
                case .simple: return .green
                case .moderate: return .orange
                case .complex: return .red
                }
            }
        }
    }
    
    struct StepPattern: Identifiable {
        let id = UUID()
        let name: String
        let pattern: String
        let category: String
        let description: String
        let example: String
    }
    
    struct CustomRule: Identifiable {
        let id = UUID()
        let name: String
        let startMarker: String
        let endMarker: String?
        let stepType: ExtractedStep.StepType
        let priority: Int
    }
    
    init(apiKey: String = "your-api-key") {
        self.client = DeepSeekClient(apiKey: apiKey)
        loadPatterns()
    }
    
    // MARK: - Extraction Methods
    
    @MainActor
    func extractSteps(from text: String) async {
        isProcessing = true
        let startTime = Date()
        
        switch mode {
        case .automatic:
            await extractStepsAutomatically(from: text)
        case .structured:
            extractStepsWithPatterns(from: text)
        case .custom:
            extractStepsWithCustomRules(from: text)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Generate metadata
        metadata = ExtractionMetadata(
            totalSteps: extractedSteps.count,
            processingTime: processingTime,
            method: mode.rawValue,
            confidence: calculateOverallConfidence(),
            textLength: text.count,
            complexity: determineComplexity()
        )
        
        isProcessing = false
    }
    
    private func extractStepsAutomatically(from text: String) async {
        let prompt = """
        Analyze this reasoning text and extract the logical steps:
        
        \(text)
        
        For each step, identify:
        1. Step number and sequence
        2. Title/summary (brief description)
        3. Full content
        4. Type (initialization, calculation, verification, decision, conclusion, intermediate)
        5. Any sub-steps
        6. Dependencies on previous steps
        7. Key concepts/keywords
        
        Format as structured data for parsing.
        """
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: [
                    Message(role: .system, content: """
                    You are an expert at analyzing reasoning processes and extracting logical steps.
                    Be precise and thorough in your analysis.
                    """),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.3
            )
            
            let response = try await client.chat.completions(request)
            
            if let content = response.choices.first?.message.content {
                extractedSteps = parseAutomaticExtraction(content, originalText: text)
            }
        } catch {
            print("Automatic extraction error: \(error)")
            // Fallback to pattern-based extraction
            extractStepsWithPatterns(from: text)
        }
    }
    
    private func extractStepsWithPatterns(from text: String) {
        var steps: [ExtractedStep] = []
        let lines = text.components(separatedBy: .newlines)
        var currentStepNumber = 1
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check each selected pattern
            for patternId in selectedPatterns {
                if let pattern = availablePatterns.first(where: { $0.id.uuidString == patternId }) {
                    if let regex = try? NSRegularExpression(pattern: pattern.pattern) {
                        let range = NSRange(trimmedLine.startIndex..., in: trimmedLine)
                        if let match = regex.firstMatch(in: trimmedLine, range: range) {
                            // Extract step content
                            let stepContent = extractStepContent(
                                from: lines,
                                startingAt: lineIndex,
                                pattern: pattern
                            )
                            
                            let step = ExtractedStep(
                                number: currentStepNumber,
                                title: extractStepTitle(from: trimmedLine, match: match),
                                content: stepContent.content,
                                type: determineStepType(from: stepContent.content),
                                subSteps: extractSubSteps(from: stepContent.content),
                                dependencies: extractDependencies(from: stepContent.content, currentStep: currentStepNumber),
                                confidence: 0.8,
                                keywords: extractKeywords(from: stepContent.content),
                                position: ExtractedStep.TextPosition(
                                    start: stepContent.start,
                                    end: stepContent.end,
                                    line: lineIndex
                                )
                            )
                            
                            steps.append(step)
                            currentStepNumber += 1
                            break
                        }
                    }
                }
            }
        }
        
        extractedSteps = steps
    }
    
    private func extractStepsWithCustomRules(from text: String) {
        var steps: [ExtractedStep] = []
        let sortedRules = customRules.sorted { $0.priority > $1.priority }
        
        for rule in sortedRules {
            var searchStart = text.startIndex
            var stepNumber = steps.count + 1
            
            while let startRange = text.range(of: rule.startMarker, range: searchStart..<text.endIndex) {
                var content: String
                var endIndex: String.Index
                
                if let endMarker = rule.endMarker {
                    if let endRange = text.range(of: endMarker, range: startRange.upperBound..<text.endIndex) {
                        content = String(text[startRange.upperBound..<endRange.lowerBound])
                        endIndex = endRange.upperBound
                    } else {
                        // No end marker found, take until next start marker or end
                        if let nextStart = text.range(of: rule.startMarker, range: startRange.upperBound..<text.endIndex) {
                            content = String(text[startRange.upperBound..<nextStart.lowerBound])
                            endIndex = nextStart.lowerBound
                        } else {
                            content = String(text[startRange.upperBound...])
                            endIndex = text.endIndex
                        }
                    }
                } else {
                    // No end marker, extract until next line or paragraph
                    if let newlineRange = text.range(of: "\n\n", range: startRange.upperBound..<text.endIndex) {
                        content = String(text[startRange.upperBound..<newlineRange.lowerBound])
                        endIndex = newlineRange.upperBound
                    } else {
                        content = String(text[startRange.upperBound...])
                        endIndex = text.endIndex
                    }
                }
                
                let step = ExtractedStep(
                    number: stepNumber,
                    title: "Step \(stepNumber): \(rule.name)",
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: rule.stepType,
                    subSteps: extractSubSteps(from: content),
                    dependencies: extractDependencies(from: content, currentStep: stepNumber),
                    confidence: 0.9,
                    keywords: extractKeywords(from: content),
                    position: ExtractedStep.TextPosition(
                        start: text.distance(from: text.startIndex, to: startRange.lowerBound),
                        end: text.distance(from: text.startIndex, to: endIndex),
                        line: text[text.startIndex..<startRange.lowerBound].components(separatedBy: .newlines).count
                    )
                )
                
                steps.append(step)
                stepNumber += 1
                searchStart = endIndex
            }
        }
        
        extractedSteps = steps.sorted { $0.position.start < $1.position.start }
    }
    
    // MARK: - Parsing Helpers
    
    private func parseAutomaticExtraction(_ content: String, originalText: String) -> [ExtractedStep] {
        // Simplified parsing - in production, use proper JSON parsing
        var steps: [ExtractedStep] = []
        
        let sections = content.components(separatedBy: "Step ")
        for (index, section) in sections.enumerated() where index > 0 {
            let lines = section.components(separatedBy: .newlines)
            guard !lines.isEmpty else { continue }
            
            let step = ExtractedStep(
                number: index,
                title: lines[0].trimmingCharacters(in: .punctuationCharacters),
                content: lines.dropFirst().joined(separator: "\n"),
                type: .intermediate,
                subSteps: [],
                dependencies: [],
                confidence: 0.85,
                keywords: [],
                position: ExtractedStep.TextPosition(start: 0, end: 0, line: 0)
            )
            
            steps.append(step)
        }
        
        return steps
    }
    
    private func extractStepContent(from lines: [String], startingAt index: Int, pattern: StepPattern) -> (content: String, start: Int, end: Int) {
        var content = ""
        var endIndex = index
        
        // Look for the next step marker or end of text
        for i in (index + 1)..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Check if this line starts a new step
            if !line.isEmpty && (line.starts(with: "Step") || line.starts(with: pattern.pattern.prefix(4))) {
                break
            }
            
            content += lines[i] + "\n"
            endIndex = i
        }
        
        let start = lines[0..<index].joined(separator: "\n").count
        let end = lines[0...endIndex].joined(separator: "\n").count
        
        return (content.trimmingCharacters(in: .whitespacesAndNewlines), start, end)
    }
    
    private func extractStepTitle(from line: String, match: NSTextCheckingResult) -> String {
        // Extract title from the matched line
        let title = line.replacingOccurrences(of: #"Step\s*\d+[:\s]*"#, with: "", options: .regularExpression)
        return title.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
    }
    
    private func determineStepType(from content: String) -> ExtractedStep.StepType {
        let lowercased = content.lowercased()
        
        if lowercased.contains("initialize") || lowercased.contains("start") || lowercased.contains("begin") {
            return .initialization
        } else if lowercased.contains("calculate") || lowercased.contains("compute") || content.contains("=") {
            return .calculation
        } else if lowercased.contains("check") || lowercased.contains("verify") || lowercased.contains("validate") {
            return .verification
        } else if lowercased.contains("if") || lowercased.contains("decide") || lowercased.contains("choose") {
            return .decision
        } else if lowercased.contains("therefore") || lowercased.contains("conclusion") || lowercased.contains("final") {
            return .conclusion
        }
        
        return .intermediate
    }
    
    private func extractSubSteps(from content: String) -> [ExtractedStep.SubStep] {
        var subSteps: [ExtractedStep.SubStep] = []
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.starts(with: "-") || trimmed.starts(with: "•") || trimmed.starts(with: "*") {
                let subStepContent = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                let isOptional = subStepContent.lowercased().contains("optional") || subStepContent.contains("if needed")
                
                subSteps.append(ExtractedStep.SubStep(
                    content: subStepContent,
                    isOptional: isOptional
                ))
            }
        }
        
        return subSteps
    }
    
    private func extractDependencies(from content: String, currentStep: Int) -> [Int] {
        var dependencies: [Int] = []
        
        // Look for references to previous steps
        let pattern = #"step\s*(\d+)|from\s*step\s*(\d+)|using\s*step\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                for i in 1..<match.numberOfRanges {
                    if let range = Range(match.range(at: i), in: content),
                       let stepNumber = Int(content[range]),
                       stepNumber < currentStep {
                        dependencies.append(stepNumber)
                    }
                }
            }
        }
        
        return Array(Set(dependencies)).sorted()
    }
    
    private func extractKeywords(from content: String) -> [String] {
        // Extract mathematical and technical keywords
        let keywords = [
            "equation", "formula", "calculate", "solve", "derivative", "integral",
            "function", "variable", "constant", "proof", "theorem", "hypothesis",
            "assume", "given", "therefore", "because", "since", "if", "then"
        ]
        
        var found: [String] = []
        let lowercased = content.lowercased()
        
        for keyword in keywords {
            if lowercased.contains(keyword) {
                found.append(keyword)
            }
        }
        
        return found
    }
    
    // MARK: - Metadata Calculation
    
    private func calculateOverallConfidence() -> Double {
        guard !extractedSteps.isEmpty else { return 0 }
        
        let totalConfidence = extractedSteps.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Double(extractedSteps.count)
    }
    
    private func determineComplexity() -> ExtractionMetadata.ComplexityLevel {
        let stepCount = extractedSteps.count
        let avgDependencies = extractedSteps.reduce(0) { $0 + $1.dependencies.count } / max(stepCount, 1)
        let hasComplexTypes = extractedSteps.contains { $0.type == .decision || $0.type == .verification }
        
        if stepCount > 10 || avgDependencies > 2 || hasComplexTypes {
            return .complex
        } else if stepCount > 5 || avgDependencies > 1 {
            return .moderate
        }
        
        return .simple
    }
    
    // MARK: - Pattern Management
    
    private func loadPatterns() {
        availablePatterns = [
            StepPattern(
                name: "Numbered Steps",
                pattern: #"^Step\s*\d+[:\s]"#,
                category: "Basic",
                description: "Matches 'Step 1:', 'Step 2:', etc.",
                example: "Step 1: Initialize variables"
            ),
            StepPattern(
                name: "Bullet Points",
                pattern: #"^[\-\*\•]\s+"#,
                category: "Basic",
                description: "Matches bullet point lists",
                example: "- Calculate the sum"
            ),
            StepPattern(
                name: "First/Next/Then",
                pattern: #"^(First|Next|Then|Finally)[,:\s]"#,
                category: "Sequential",
                description: "Matches sequential markers",
                example: "First, we need to..."
            ),
            StepPattern(
                name: "Numbered List",
                pattern: #"^\d+\.\s+"#,
                category: "Basic",
                description: "Matches numbered lists",
                example: "1. Check the input"
            ),
            StepPattern(
                name: "Action Verbs",
                pattern: #"^(Calculate|Compute|Verify|Check|Determine|Find)[:\s]"#,
                category: "Action",
                description: "Matches action-oriented steps",
                example: "Calculate: the total sum"
            )
        ]
        
        // Select common patterns by default
        selectedPatterns = Set(availablePatterns.prefix(3).map { $0.id.uuidString })
    }
    
    func togglePattern(_ pattern: StepPattern) {
        if selectedPatterns.contains(pattern.id.uuidString) {
            selectedPatterns.remove(pattern.id.uuidString)
        } else {
            selectedPatterns.insert(pattern.id.uuidString)
        }
    }
    
    func addCustomRule(_ rule: CustomRule) {
        customRules.append(rule)
    }
    
    func removeCustomRule(_ rule: CustomRule) {
        customRules.removeAll { $0.id == rule.id }
    }
}

// MARK: - UI Components

struct InputSection: View {
    @Binding var inputText: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Input Text", systemImage: "text.alignleft")
                .font(.headline)
            
            TextEditor(text: $inputText)
                .font(.body)
                .frame(height: 150)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    Group {
                        if inputText.isEmpty {
                            Text(placeholder)
                                .foregroundColor(.secondary)
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
            
            HStack {
                Text("\(inputText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { inputText = "" }) {
                    Text("Clear")
                        .font(.caption)
                }
                .disabled(inputText.isEmpty)
            }
        }
    }
}

struct ModeSelector: View {
    @Binding var selectedMode: ReasoningStepsExtractor.ExtractionMode
    let onChange: (ReasoningStepsExtractor.ExtractionMode) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extraction Mode")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(ReasoningStepsExtractor.ExtractionMode.allCases, id: \.self) { mode in
                    ModeOption(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        action: {
                            selectedMode = mode
                            onChange(mode)
                        }
                    )
                }
            }
        }
    }
}

struct ModeOption: View {
    let mode: ReasoningStepsExtractor.ExtractionMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExtractionControls: View {
    let onExtract: () -> Void
    let onVisualize: () -> Void
    let isProcessing: Bool
    let hasResults: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExtract) {
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Extracting...")
                    }
                } else {
                    Label("Extract Steps", systemImage: "text.magnifyingglass")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
            
            if hasResults {
                Button(action: onVisualize) {
                    Label("Visualize", systemImage: "chart.xyaxis.line")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct ExtractedStepsView: View {
    let steps: [StepsExtractor.ExtractedStep]
    let metadata: StepsExtractor.ExtractionMetadata?
    @State private var selectedStep: StepsExtractor.ExtractedStep?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Metadata
            if let metadata = metadata {
                MetadataCard(metadata: metadata)
            }
            
            // Steps header
            HStack {
                Label("Extracted Steps", systemImage: "list.number")
                    .font(.headline)
                
                Spacer()
                
                Text("\(steps.count) steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Steps list
            VStack(spacing: 8) {
                ForEach(steps) { step in
                    StepCard(
                        step: step,
                        isSelected: selectedStep?.id == step.id,
                        onSelect: { selectedStep = step }
                    )
                }
            }
            
            // Selected step detail
            if let step = selectedStep {
                StepDetailView(step: step)
            }
        }
    }
}

struct MetadataCard: View {
    let metadata: StepsExtractor.ExtractionMetadata
    
    var body: some View {
        HStack(spacing: 16) {
            MetadataItem(
                icon: "number",
                label: "Steps",
                value: "\(metadata.totalSteps)"
            )
            
            MetadataItem(
                icon: "timer",
                label: "Time",
                value: String(format: "%.2fs", metadata.processingTime)
            )
            
            MetadataItem(
                icon: "percent",
                label: "Confidence",
                value: "\(Int(metadata.confidence * 100))%"
            )
            
            MetadataItem(
                icon: "chart.bar",
                label: "Complexity",
                value: complexityText(metadata.complexity),
                valueColor: metadata.complexity.color
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func complexityText(_ complexity: StepsExtractor.ExtractionMetadata.ComplexityLevel) -> String {
        switch complexity {
        case .simple: return "Simple"
        case .moderate: return "Moderate"
        case .complex: return "Complex"
        }
    }
}

struct MetadataItem: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StepCard: View {
    let step: StepsExtractor.ExtractedStep
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Step number and type
                VStack(spacing: 4) {
                    Text("\(step.number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(step.type.color))
                    
                    Image(systemName: step.type.icon)
                        .font(.caption2)
                        .foregroundColor(step.type.color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(step.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Metadata
                    HStack(spacing: 12) {
                        if !step.dependencies.isEmpty {
                            Label("Depends on: \(step.dependencies.map(String.init).joined(separator: ", "))", systemImage: "link")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        if !step.subSteps.isEmpty {
                            Label("\(step.subSteps.count) sub-steps", systemImage: "list.dash")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        ConfidenceBadge(confidence: step.confidence)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var color: Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color))
    }
}

struct StepDetailView: View {
    let step: StepsExtractor.ExtractedStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step Details")
                .font(.headline)
            
            // Full content
            VStack(alignment: .leading, spacing: 8) {
                Text("Content")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(step.content)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            
            // Sub-steps
            if !step.subSteps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sub-steps")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(step.subSteps.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(step.subSteps[index].isOptional ? Color.orange : Color.blue)
                                .frame(width: 6, height: 6)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.subSteps[index].content)
                                    .font(.caption)
                                
                                if step.subSteps[index].isOptional {
                                    Text("Optional")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
            }
            
            // Keywords
            if !step.keywords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keywords")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(step.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Position info
            HStack {
                Label("Line \(step.position.line)", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Characters \(step.position.start)-\(step.position.end)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PatternLibrarySection: View {
    let patterns: [StepsExtractor.StepPattern]
    let selectedPatterns: Set<String>
    let onTogglePattern: (StepsExtractor.StepPattern) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pattern Library")
                .font(.headline)
            
            Text("Select patterns to use for extraction")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(patterns) { pattern in
                    PatternRow(
                        pattern: pattern,
                        isSelected: selectedPatterns.contains(pattern.id.uuidString),
                        onToggle: { onTogglePattern(pattern) }
                    )
                }
            }
        }
    }
}

struct PatternRow: View {
    let pattern: StepsExtractor.StepPattern
    let isSelected: Bool
    let onToggle: () -> Void
    
    @State private var showingExample = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .blue : .secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pattern.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(pattern.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingExample.toggle() }) {
                        Text(showingExample ? "Hide" : "Example")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showingExample {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pattern: \(pattern.pattern)")
                        .font(.caption)
                        .fontFamily(.monospaced)
                        .padding(4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Text("Example: \(pattern.example)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 32)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CustomRulesEditor: View {
    let rules: [StepsExtractor.CustomRule]
    let onAddRule: (StepsExtractor.CustomRule) -> Void
    let onRemoveRule: (StepsExtractor.CustomRule) -> Void
    
    @State private var showingAddRule = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Rules")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            if rules.isEmpty {
                Text("No custom rules defined")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(rules) { rule in
                        CustomRuleRow(
                            rule: rule,
                            onRemove: { onRemoveRule(rule) }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRule) {
            AddCustomRuleView { rule in
                onAddRule(rule)
                showingAddRule = false
            }
        }
    }
}

struct CustomRuleRow: View {
    let rule: StepsExtractor.CustomRule
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Label(rule.startMarker, systemImage: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if let endMarker = rule.endMarker {
                        Label(endMarker, systemImage: "arrow.left")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text("Priority: \(rule.priority)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AddCustomRuleView: View {
    let onAdd: (StepsExtractor.CustomRule) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var startMarker = ""
    @State private var endMarker = ""
    @State private var useEndMarker = false
    @State private var stepType: StepsExtractor.ExtractedStep.StepType = .intermediate
    @State private var priority = 5
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Information") {
                    TextField("Rule Name", text: $name)
                    
                    Picker("Step Type", selection: $stepType) {
                        Text("Initialization").tag(StepsExtractor.ExtractedStep.StepType.initialization)
                        Text("Calculation").tag(StepsExtractor.ExtractedStep.StepType.calculation)
                        Text("Verification").tag(StepsExtractor.ExtractedStep.StepType.verification)
                        Text("Decision").tag(StepsExtractor.ExtractedStep.StepType.decision)
                        Text("Conclusion").tag(StepsExtractor.ExtractedStep.StepType.conclusion)
                        Text("Intermediate").tag(StepsExtractor.ExtractedStep.StepType.intermediate)
                    }
                    
                    Stepper("Priority: \(priority)", value: $priority, in: 1...10)
                }
                
                Section("Markers") {
                    TextField("Start Marker", text: $startMarker)
                        .textFieldStyle(.roundedBorder)
                    
                    Toggle("Use End Marker", isOn: $useEndMarker)
                    
                    if useEndMarker {
                        TextField("End Marker", text: $endMarker)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section {
                    Text("The rule will extract text between the start marker and end marker (if specified)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Custom Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let rule = StepsExtractor.CustomRule(
                            name: name,
                            startMarker: startMarker,
                            endMarker: useEndMarker ? endMarker : nil,
                            stepType: stepType,
                            priority: priority
                        )
                        onAdd(rule)
                    }
                    .disabled(name.isEmpty || startMarker.isEmpty)
                }
            }
        }
    }
}

// MARK: - Visualization

struct StepsVisualizationView: View {
    let steps: [StepsExtractor.ExtractedStep]
    @Environment(\.dismiss) var dismiss
    @State private var selectedVisualization: VisualizationType = .flow
    
    enum VisualizationType: String, CaseIterable {
        case flow = "Flow Chart"
        case dependency = "Dependencies"
        case timeline = "Timeline"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Visualization", selection: $selectedVisualization) {
                    ForEach(VisualizationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                switch selectedVisualization {
                case .flow:
                    FlowChartView(steps: steps)
                case .dependency:
                    DependencyGraphView(steps: steps)
                case .timeline:
                    TimelineView(steps: steps)
                }
            }
            .navigationTitle("Step Visualization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FlowChartView: View {
    let steps: [StepsExtractor.ExtractedStep]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(steps) { step in
                    FlowNode(step: step)
                    
                    if step.number < steps.count {
                        Image(systemName: "arrow.down")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct FlowNode: View {
    let step: StepsExtractor.ExtractedStep
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: step.type.icon)
                    .foregroundColor(step.type.color)
                
                Text("Step \(step.number)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Text(step.title)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: 200)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(step.type.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(step.type.color, lineWidth: 2)
                        )
                )
        }
    }
}

struct DependencyGraphView: View {
    let steps: [StepsExtractor.ExtractedStep]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw dependency lines
                ForEach(steps) { step in
                    ForEach(step.dependencies, id: \.self) { depNumber in
                        if let depStep = steps.first(where: { $0.number == depNumber }) {
                            DependencyLine(
                                from: nodePosition(for: depStep, in: geometry.size),
                                to: nodePosition(for: step, in: geometry.size)
                            )
                        }
                    }
                }
                
                // Draw nodes
                ForEach(steps) { step in
                    DependencyNode(step: step)
                        .position(nodePosition(for: step, in: geometry.size))
                }
            }
        }
        .padding()
    }
    
    private func nodePosition(for step: StepsExtractor.ExtractedStep, in size: CGSize) -> CGPoint {
        let angle = (Double(step.number - 1) / Double(steps.count)) * 2 * .pi
        let radius = min(size.width, size.height) * 0.35
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        let x = centerX + radius * cos(angle)
        let y = centerY + radius * sin(angle)
        
        return CGPoint(x: x, y: y)
    }
}

struct DependencyLine: View {
    let from: CGPoint
    let to: CGPoint
    
    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
    }
}

struct DependencyNode: View {
    let step: StepsExtractor.ExtractedStep
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(step.number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(step.type.color))
            
            Text(step.title)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
    }
}

struct TimelineView: View {
    let steps: [StepsExtractor.ExtractedStep]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 16) {
                        // Timeline
                        VStack(spacing: 0) {
                            Circle()
                                .fill(step.type.color)
                                .frame(width: 12, height: 12)
                            
                            if step.number < steps.count {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 2, height: 60)
                            }
                        }
                        
                        // Content
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Step \(step.number): \(step.title)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if !step.dependencies.isEmpty {
                                Text("Depends on: \(step.dependencies.map(String.init).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Text("\(step.subSteps.count) sub-steps")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 20)
                        
                        Spacer()
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Helper Views

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

struct ReasoningStepsExtractorDemo: View {
    var body: some View {
        ReasoningStepsExtractor()
    }
}