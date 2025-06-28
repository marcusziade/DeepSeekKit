import SwiftUI
import DeepSeekKit

// Display reasoning in SwiftUI
struct ReasoningDisplayView: View {
    @StateObject private var viewModel: ReasoningDisplayViewModel
    @State private var selectedExample = 0
    @State private var displayMode: DisplayMode = .formatted
    
    enum DisplayMode: String, CaseIterable {
        case formatted = "Formatted"
        case timeline = "Timeline"
        case graph = "Graph"
        case markdown = "Markdown"
        
        var icon: String {
            switch self {
            case .formatted: return "text.alignleft"
            case .timeline: return "timeline"
            case .graph: return "point.3.connected.trianglepath.dotted"
            case .markdown: return "doc.richtext"
            }
        }
    }
    
    let examples = [
        (
            title: "Math Problem",
            prompt: "If a store offers a 25% discount on an item that costs $80, and then applies an additional 10% off the discounted price, what is the final price?"
        ),
        (
            title: "Logic Puzzle",
            prompt: "There are 5 houses in a row, each painted a different color. The green house is immediately to the right of the white house. The red house is in the middle. The blue house is at one of the ends. Where is each colored house?"
        ),
        (
            title: "Code Review",
            prompt: "Review this function and suggest improvements:\n```\nfunc fibonacci(n: Int) -> Int {\n    if n <= 1 { return n }\n    return fibonacci(n-1) + fibonacci(n-2)\n}\n```"
        )
    ]
    
    init(apiKey: String) {
        _viewModel = StateObject(wrappedValue: ReasoningDisplayViewModel(apiKey: apiKey))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Example selector
            ExampleSelector(
                examples: examples.map { $0.title },
                selectedIndex: $selectedExample,
                onSelect: { loadExample(at: $0) }
            )
            
            // Display mode selector
            DisplayModeSelector(
                selectedMode: $displayMode
            )
            
            Divider()
            
            // Content area
            ScrollView {
                if viewModel.isLoading {
                    LoadingView()
                } else if let reasoning = viewModel.currentReasoning {
                    ReasoningContentContainer(
                        reasoning: reasoning,
                        displayMode: displayMode
                    )
                } else {
                    EmptyStatePrompt(
                        onLoadExample: { loadExample(at: 0) }
                    )
                }
            }
        }
        .navigationTitle("Reasoning Display")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.currentReasoning != nil {
                    ShareButton(reasoning: viewModel.currentReasoning!)
                }
            }
        }
    }
    
    private func loadExample(at index: Int) {
        selectedExample = index
        let example = examples[index]
        Task {
            await viewModel.generateReasoning(for: example.prompt)
        }
    }
}

// MARK: - View Model

class ReasoningDisplayViewModel: ObservableObject {
    @Published var currentReasoning: ProcessedReasoning?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let client: DeepSeekClient
    
    struct ProcessedReasoning {
        let prompt: String
        let answer: String
        let reasoning: String
        let steps: [Step]
        let insights: [Insight]
        let metadata: Metadata
        
        struct Step {
            let number: Int
            let title: String
            let content: String
            let subSteps: [String]
            let duration: TimeInterval? // Simulated
            let confidence: Double? // Simulated
        }
        
        struct Insight {
            let type: InsightType
            let content: String
            let relatedSteps: [Int]
            
            enum InsightType {
                case assumption, calculation, verification, conclusion
                
                var color: Color {
                    switch self {
                    case .assumption: return .orange
                    case .calculation: return .blue
                    case .verification: return .green
                    case .conclusion: return .purple
                    }
                }
                
                var icon: String {
                    switch self {
                    case .assumption: return "questionmark.circle"
                    case .calculation: return "number"
                    case .verification: return "checkmark.shield"
                    case .conclusion: return "flag.fill"
                    }
                }
            }
        }
        
        struct Metadata {
            let model: String
            let totalTokens: Int
            let reasoningTokens: Int
            let processingTime: TimeInterval
            let timestamp: Date
        }
    }
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
    }
    
    @MainActor
    func generateReasoning(for prompt: String) async {
        isLoading = true
        error = nil
        
        let startTime = Date()
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.3
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                let processingTime = Date().timeIntervalSince(startTime)
                
                currentReasoning = processResponse(
                    prompt: prompt,
                    answer: choice.message.content,
                    reasoning: choice.message.reasoningContent ?? "",
                    model: response.model,
                    usage: response.usage,
                    processingTime: processingTime
                )
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func processResponse(
        prompt: String,
        answer: String,
        reasoning: String,
        model: String,
        usage: ChatCompletionResponse.Usage?,
        processingTime: TimeInterval
    ) -> ProcessedReasoning {
        let steps = parseSteps(from: reasoning)
        let insights = extractInsights(from: reasoning, steps: steps)
        
        let metadata = ProcessedReasoning.Metadata(
            model: model,
            totalTokens: usage?.totalTokens ?? 0,
            reasoningTokens: usage?.reasoningTokens ?? 0,
            processingTime: processingTime,
            timestamp: Date()
        )
        
        return ProcessedReasoning(
            prompt: prompt,
            answer: answer,
            reasoning: reasoning,
            steps: steps,
            insights: insights,
            metadata: metadata
        )
    }
    
    private func parseSteps(from reasoning: String) -> [ProcessedReasoning.Step] {
        var steps: [ProcessedReasoning.Step] = []
        
        // Pattern to match steps
        let stepPattern = #"(?:Step|STEP)\s*(\d+)[:\s]*([^\n]+)(.*?)(?=Step|STEP|\z)"#s
        
        if let regex = try? NSRegularExpression(pattern: stepPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: reasoning, range: NSRange(reasoning.startIndex..., in: reasoning))
            
            for match in matches {
                if let numberRange = Range(match.range(at: 1), in: reasoning),
                   let titleRange = Range(match.range(at: 2), in: reasoning),
                   let contentRange = Range(match.range(at: 3), in: reasoning) {
                    
                    let number = Int(reasoning[numberRange]) ?? 0
                    let title = String(reasoning[titleRange])
                    let content = String(reasoning[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Extract sub-steps
                    let subSteps = extractSubSteps(from: content)
                    
                    // Simulate duration and confidence
                    let duration = TimeInterval.random(in: 0.5...2.0)
                    let confidence = Double.random(in: 0.7...0.99)
                    
                    steps.append(ProcessedReasoning.Step(
                        number: number,
                        title: title.trimmingCharacters(in: .punctuationCharacters),
                        content: content,
                        subSteps: subSteps,
                        duration: duration,
                        confidence: confidence
                    ))
                }
            }
        }
        
        // If no steps found, create a single step
        if steps.isEmpty {
            steps.append(ProcessedReasoning.Step(
                number: 1,
                title: "Analysis",
                content: reasoning,
                subSteps: [],
                duration: processingTime,
                confidence: 0.95
            ))
        }
        
        return steps
    }
    
    private func extractSubSteps(from content: String) -> [String] {
        var subSteps: [String] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "-") || trimmed.starts(with: "•") || trimmed.starts(with: "*") {
                subSteps.append(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
            }
        }
        
        return subSteps
    }
    
    private func extractInsights(from reasoning: String, steps: [ProcessedReasoning.Step]) -> [ProcessedReasoning.Insight] {
        var insights: [ProcessedReasoning.Insight] = []
        
        // Extract assumptions
        if reasoning.lowercased().contains("assum") {
            insights.append(ProcessedReasoning.Insight(
                type: .assumption,
                content: "Initial assumptions made for the problem",
                relatedSteps: [1]
            ))
        }
        
        // Extract calculations
        let calculationPattern = #"\d+\s*[+\-*/]\s*\d+"#
        if reasoning.range(of: calculationPattern, options: .regularExpression) != nil {
            insights.append(ProcessedReasoning.Insight(
                type: .calculation,
                content: "Mathematical calculations performed",
                relatedSteps: steps.filter { $0.content.range(of: calculationPattern, options: .regularExpression) != nil }.map { $0.number }
            ))
        }
        
        // Extract verifications
        if reasoning.lowercased().contains("check") || reasoning.lowercased().contains("verif") {
            insights.append(ProcessedReasoning.Insight(
                type: .verification,
                content: "Verification steps to ensure accuracy",
                relatedSteps: steps.filter { $0.content.lowercased().contains("check") || $0.content.lowercased().contains("verif") }.map { $0.number }
            ))
        }
        
        // Extract conclusions
        if reasoning.lowercased().contains("therefore") || reasoning.lowercased().contains("conclusion") {
            insights.append(ProcessedReasoning.Insight(
                type: .conclusion,
                content: "Final conclusion reached",
                relatedSteps: [steps.last?.number ?? steps.count]
            ))
        }
        
        return insights
    }
}

// MARK: - UI Components

struct ExampleSelector: View {
    let examples: [String]
    @Binding var selectedIndex: Int
    let onSelect: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(examples.indices, id: \.self) { index in
                    Button(action: { 
                        selectedIndex = index
                        onSelect(index)
                    }) {
                        Text(examples[index])
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedIndex == index ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedIndex == index ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding()
        }
    }
}

struct DisplayModeSelector: View {
    @Binding var selectedMode: ReasoningDisplayView.DisplayMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReasoningDisplayView.DisplayMode.allCases, id: \.self) { mode in
                Button(action: { selectedMode = mode }) {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.title3)
                        Text(mode.rawValue)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedMode == mode ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedMode == mode ? .blue : .secondary)
                }
            }
        }
    }
}

struct ReasoningContentContainer: View {
    let reasoning: ReasoningDisplayViewModel.ProcessedReasoning
    let displayMode: ReasoningDisplayView.DisplayMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Metadata card
            MetadataCard(metadata: reasoning.metadata)
            
            // Prompt and answer
            PromptAnswerSection(
                prompt: reasoning.prompt,
                answer: reasoning.answer
            )
            
            // Display based on mode
            switch displayMode {
            case .formatted:
                FormattedReasoningDisplay(reasoning: reasoning)
            case .timeline:
                TimelineReasoningDisplay(reasoning: reasoning)
            case .graph:
                GraphReasoningDisplay(reasoning: reasoning)
            case .markdown:
                MarkdownReasoningDisplay(reasoning: reasoning)
            }
        }
        .padding()
    }
}

struct MetadataCard: View {
    let metadata: ReasoningDisplayViewModel.ProcessedReasoning.Metadata
    
    var body: some View {
        HStack(spacing: 20) {
            MetadataItem(
                icon: "cpu",
                label: "Model",
                value: metadata.model
            )
            
            MetadataItem(
                icon: "doc.text",
                label: "Tokens",
                value: "\(metadata.totalTokens)"
            )
            
            MetadataItem(
                icon: "brain",
                label: "Reasoning",
                value: "\(metadata.reasoningTokens)"
            )
            
            MetadataItem(
                icon: "timer",
                label: "Time",
                value: String(format: "%.2fs", metadata.processingTime)
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MetadataItem: View {
    let icon: String
    let label: String
    let value: String
    
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

struct PromptAnswerSection: View {
    let prompt: String
    let answer: String
    @State private var showingPrompt = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prompt
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { showingPrompt.toggle() }) {
                    HStack {
                        Label("Prompt", systemImage: "questionmark.circle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Image(systemName: showingPrompt ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
                
                if showingPrompt {
                    Text(prompt)
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Answer
            VStack(alignment: .leading, spacing: 8) {
                Label("Answer", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(answer)
                    .font(.body)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Display Modes

struct FormattedReasoningDisplay: View {
    let reasoning: ReasoningDisplayViewModel.ProcessedReasoning
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Insights
            if !reasoning.insights.isEmpty {
                InsightsSection(insights: reasoning.insights)
            }
            
            // Steps
            Text("Reasoning Steps")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(reasoning.steps, id: \.number) { step in
                    FormattedStepView(step: step)
                }
            }
        }
    }
}

struct FormattedStepView: View {
    let step: ReasoningDisplayViewModel.ProcessedReasoning.Step
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    // Step number
                    Text("\(step.number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.blue))
                    
                    // Title
                    Text(step.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Confidence indicator
                    if let confidence = step.confidence {
                        ConfidenceIndicator(confidence: confidence)
                    }
                    
                    // Expand/collapse
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(step.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                    
                    // Sub-steps
                    if !step.subSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(step.subSteps, id: \.self) { subStep in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color.secondary)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 4)
                                    
                                    Text(subStep)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 44)
                    }
                    
                    // Duration
                    if let duration = step.duration {
                        Text("~\(String(format: "%.1f", duration))s")
                            .font(.caption2)
                            .foregroundColor(.tertiary)
                            .padding(.leading, 36)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct InsightsSection: View {
    let insights: [ReasoningDisplayViewModel.ProcessedReasoning.Insight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key Insights")
                .font(.headline)
            
            ForEach(insights.indices, id: \.self) { index in
                InsightRow(insight: insights[index])
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
}

struct InsightRow: View {
    let insight: ReasoningDisplayViewModel.ProcessedReasoning.Insight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.type.icon)
                .font(.body)
                .foregroundColor(insight.type.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.content)
                    .font(.subheadline)
                
                if !insight.relatedSteps.isEmpty {
                    Text("Related to steps: \(insight.relatedSteps.map(String.init).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct TimelineReasoningDisplay: View {
    let reasoning: ReasoningDisplayViewModel.ProcessedReasoning
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reasoning Timeline")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(reasoning.steps, id: \.number) { step in
                        TimelineStepView(
                            step: step,
                            isLast: step.number == reasoning.steps.last?.number
                        )
                    }
                }
                .padding(.vertical)
            }
            
            // Legend
            TimelineLegend()
        }
    }
}

struct TimelineStepView: View {
    let step: ReasoningDisplayViewModel.ProcessedReasoning.Step
    let isLast: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timeline dot and line
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    
                    if !isLast {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 2, height: 120)
                    }
                }
                .frame(width: 12)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(step.number)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(step.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .frame(width: 150, alignment: .leading)
                    
                    if let duration = step.duration {
                        Label(
                            String(format: "%.1fs", duration),
                            systemImage: "timer"
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    
                    if let confidence = step.confidence {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption2)
                            Text("\(Int(confidence * 100))%")
                                .font(.caption2)
                        }
                        .foregroundColor(.green)
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(.trailing, 20)
    }
}

struct TimelineLegend: View {
    var body: some View {
        HStack(spacing: 20) {
            Label("Step", systemImage: "circle.fill")
                .font(.caption2)
                .foregroundColor(.blue)
            
            Label("Duration", systemImage: "timer")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Label("Confidence", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption2)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct GraphReasoningDisplay: View {
    let reasoning: ReasoningDisplayViewModel.ProcessedReasoning
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reasoning Graph")
                .font(.headline)
            
            // Simplified graph representation
            ReasoningGraphView(steps: reasoning.steps, insights: reasoning.insights)
                .frame(height: 300)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            // Node legend
            GraphLegend()
        }
    }
}

struct ReasoningGraphView: View {
    let steps: [ReasoningDisplayViewModel.ProcessedReasoning.Step]
    let insights: [ReasoningDisplayViewModel.ProcessedReasoning.Insight]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw connections
                ForEach(0..<steps.count-1, id: \.self) { index in
                    Path { path in
                        let start = nodePosition(for: index, in: geometry.size)
                        let end = nodePosition(for: index + 1, in: geometry.size)
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                }
                
                // Draw nodes
                ForEach(steps.indices, id: \.self) { index in
                    let position = nodePosition(for: index, in: geometry.size)
                    
                    GraphNode(step: steps[index])
                        .position(position)
                }
                
                // Draw insight connections
                ForEach(insights.indices, id: \.self) { index in
                    let insight = insights[index]
                    ForEach(insight.relatedSteps, id: \.self) { stepNumber in
                        if let stepIndex = steps.firstIndex(where: { $0.number == stepNumber }) {
                            Path { path in
                                let stepPos = nodePosition(for: stepIndex, in: geometry.size)
                                let insightPos = insightPosition(for: index, in: geometry.size)
                                path.move(to: stepPos)
                                path.addLine(to: insightPos)
                            }
                            .stroke(insight.type.color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        }
                    }
                    
                    InsightNode(insight: insight)
                        .position(insightPosition(for: index, in: geometry.size))
                }
            }
        }
    }
    
    private func nodePosition(for index: Int, in size: CGSize) -> CGPoint {
        let spacing = size.width / CGFloat(steps.count + 1)
        let x = spacing * CGFloat(index + 1)
        let y = size.height / 2
        return CGPoint(x: x, y: y)
    }
    
    private func insightPosition(for index: Int, in size: CGSize) -> CGPoint {
        let spacing = size.width / CGFloat(insights.count + 1)
        let x = spacing * CGFloat(index + 1)
        let y = size.height * 0.8
        return CGPoint(x: x, y: y)
    }
}

struct GraphNode: View {
    let step: ReasoningDisplayViewModel.ProcessedReasoning.Step
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(step.number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.blue))
            
            Text(step.title)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 60)
        }
    }
}

struct InsightNode: View {
    let insight: ReasoningDisplayViewModel.ProcessedReasoning.Insight
    
    var body: some View {
        Image(systemName: insight.type.icon)
            .font(.caption)
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(insight.type.color))
    }
}

struct GraphLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legend")
                .font(.caption)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    Text("Step")
                        .font(.caption2)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                    Text("Assumption")
                        .font(.caption2)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    Text("Verification")
                        .font(.caption2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MarkdownReasoningDisplay: View {
    let reasoning: ReasoningDisplayViewModel.ProcessedReasoning
    @State private var markdown: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Markdown Export")
                    .font(.headline)
                
                Spacer()
                
                Button(action: copyMarkdown) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                Text(markdown)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            generateMarkdown()
        }
    }
    
    private func generateMarkdown() {
        var md = "# Reasoning Analysis\n\n"
        
        md += "## Prompt\n\(reasoning.prompt)\n\n"
        
        md += "## Answer\n\(reasoning.answer)\n\n"
        
        md += "## Reasoning Process\n\n"
        
        for step in reasoning.steps {
            md += "### Step \(step.number): \(step.title)\n\n"
            md += "\(step.content)\n\n"
            
            if !step.subSteps.isEmpty {
                for subStep in step.subSteps {
                    md += "- \(subStep)\n"
                }
                md += "\n"
            }
        }
        
        if !reasoning.insights.isEmpty {
            md += "## Insights\n\n"
            for insight in reasoning.insights {
                md += "- **\(insight.type)**: \(insight.content)\n"
            }
        }
        
        md += "\n---\n"
        md += "*Generated by \(reasoning.metadata.model) in \(String(format: "%.2f", reasoning.metadata.processingTime))s*\n"
        
        markdown = md
    }
    
    private func copyMarkdown() {
        #if os(iOS)
        UIPasteboard.general.string = markdown
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        #endif
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    @State private var rotation = 0.0
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 50))
                .foregroundColor(.purple)
                .rotationEffect(.degrees(rotation))
                .animation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: rotation
                )
                .onAppear {
                    rotation = 10
                }
            
            Text("Reasoning in progress...")
                .font(.headline)
            
            ProgressView()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStatePrompt: View {
    let onLoadExample: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Select an Example")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose from the examples above to see how reasoning is displayed")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onLoadExample) {
                Text("Load First Example")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var color: Color {
        if confidence > 0.9 { return .green }
        if confidence > 0.7 { return .orange }
        return .red
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(Double(index) < confidence * 5 ? color : Color.gray.opacity(0.3))
                    .frame(width: 3, height: 10)
            }
        }
    }
}

struct ShareButton: View {
    let reasoning: ReasoningDisplayViewModel.ProcessedReasoning
    @State private var showingShareSheet = false
    
    var body: some View {
        Button(action: { showingShareSheet = true }) {
            Image(systemName: "square.and.arrow.up")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [createShareContent()])
        }
    }
    
    private func createShareContent() -> String {
        """
        Reasoning Analysis
        
        Prompt: \(reasoning.prompt)
        
        Answer: \(reasoning.answer)
        
        Steps:
        \(reasoning.steps.map { "Step \($0.number): \($0.title)" }.joined(separator: "\n"))
        
        Generated in \(String(format: "%.2f", reasoning.metadata.processingTime))s
        """
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Demo

struct ReasoningDisplayDemo: View {
    let apiKey: String
    
    var body: some View {
        ReasoningDisplayView(apiKey: apiKey)
    }
}