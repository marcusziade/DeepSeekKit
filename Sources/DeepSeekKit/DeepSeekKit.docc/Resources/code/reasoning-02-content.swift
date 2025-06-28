import SwiftUI
import DeepSeekKit

// Access reasoning content in responses
struct ReasoningContentView: View {
    @StateObject private var client: DeepSeekClient
    @State private var question = ""
    @State private var isLoading = false
    @State private var response: ReasoningResponse?
    @State private var error: Error?
    @State private var showingReasoning = true
    @State private var selectedView: ViewMode = .split
    
    enum ViewMode: String, CaseIterable {
        case split = "Split View"
        case reasoning = "Reasoning Only"
        case answer = "Answer Only"
        case raw = "Raw JSON"
    }
    
    struct ReasoningResponse {
        let answer: String
        let reasoning: String?
        let tokens: TokenUsage
        let model: String
        let requestId: String
        
        struct TokenUsage {
            let prompt: Int
            let reasoning: Int
            let completion: Int
            let total: Int
        }
    }
    
    init(apiKey: String) {
        _client = StateObject(wrappedValue: DeepSeekClient(apiKey: apiKey))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Input section
            VStack(alignment: .leading, spacing: 12) {
                Text("Ask a reasoning question")
                    .font(.headline)
                
                TextEditor(text: $question)
                    .font(.body)
                    .frame(height: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                HStack {
                    Button(action: submitQuestion) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Submit")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(question.isEmpty || isLoading)
                    
                    Spacer()
                    
                    Picker("View", selection: $selectedView) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .fixedSize()
                }
            }
            .padding()
            
            Divider()
            
            // Response section
            if let response = response {
                ResponseContentView(
                    response: response,
                    viewMode: selectedView,
                    showingReasoning: $showingReasoning
                )
            } else if let error = error {
                ErrorView(error: error)
                    .padding()
            } else {
                EmptyStateView()
            }
        }
        .navigationTitle("Reasoning Content")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if response != nil {
                    Button(action: copyToClipboard) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
    
    private func submitQuestion() {
        Task {
            await performReasoningRequest()
        }
    }
    
    @MainActor
    private func performReasoningRequest() async {
        isLoading = true
        error = nil
        response = nil
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .user, content: question)
                ],
                temperature: 0.3
            )
            
            let result = try await client.chat.completions(request)
            
            if let choice = result.choices.first {
                response = ReasoningResponse(
                    answer: choice.message.content,
                    reasoning: choice.message.reasoningContent,
                    tokens: ReasoningResponse.TokenUsage(
                        prompt: result.usage?.promptTokens ?? 0,
                        reasoning: result.usage?.reasoningTokens ?? 0,
                        completion: result.usage?.completionTokens ?? 0,
                        total: result.usage?.totalTokens ?? 0
                    ),
                    model: result.model,
                    requestId: result.id
                )
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func copyToClipboard() {
        guard let response = response else { return }
        
        let content: String
        switch selectedView {
        case .split:
            content = """
            QUESTION: \(question)
            
            REASONING:
            \(response.reasoning ?? "No reasoning provided")
            
            ANSWER:
            \(response.answer)
            """
        case .reasoning:
            content = response.reasoning ?? "No reasoning provided"
        case .answer:
            content = response.answer
        case .raw:
            content = formatRawResponse(response)
        }
        
        #if os(iOS)
        UIPasteboard.general.string = content
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #endif
    }
    
    private func formatRawResponse(_ response: ReasoningResponse) -> String {
        """
        {
            "model": "\(response.model)",
            "request_id": "\(response.requestId)",
            "message": {
                "content": "\(response.answer)",
                "reasoning_content": "\(response.reasoning ?? "null")"
            },
            "usage": {
                "prompt_tokens": \(response.tokens.prompt),
                "reasoning_tokens": \(response.tokens.reasoning),
                "completion_tokens": \(response.tokens.completion),
                "total_tokens": \(response.tokens.total)
            }
        }
        """
    }
}

// MARK: - Response Content View

struct ResponseContentView: View {
    let response: ReasoningContentView.ReasoningResponse
    let viewMode: ReasoningContentView.ViewMode
    @Binding var showingReasoning: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Token usage
                TokenUsageCard(tokens: response.tokens)
                
                // Content based on view mode
                switch viewMode {
                case .split:
                    SplitContentView(
                        response: response,
                        showingReasoning: $showingReasoning
                    )
                case .reasoning:
                    ReasoningOnlyView(reasoning: response.reasoning)
                case .answer:
                    AnswerOnlyView(answer: response.answer)
                case .raw:
                    RawJSONView(response: response)
                }
            }
            .padding()
        }
    }
}

// MARK: - View Mode Components

struct SplitContentView: View {
    let response: ReasoningContentView.ReasoningResponse
    @Binding var showingReasoning: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Answer section
            VStack(alignment: .leading, spacing: 8) {
                Label("Answer", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text(response.answer)
                    .font(.body)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Reasoning section
            if let reasoning = response.reasoning {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Reasoning Process", systemImage: "brain")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        Spacer()
                        
                        Button(action: { showingReasoning.toggle() }) {
                            Image(systemName: showingReasoning ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                    }
                    
                    if showingReasoning {
                        FormattedReasoningView(content: reasoning)
                    }
                }
            }
        }
    }
}

struct ReasoningOnlyView: View {
    let reasoning: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reasoning Process", systemImage: "brain")
                .font(.headline)
                .foregroundColor(.purple)
            
            if let reasoning = reasoning {
                FormattedReasoningView(content: reasoning)
            } else {
                Text("No reasoning content available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

struct AnswerOnlyView: View {
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Answer", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            Text(answer)
                .font(.body)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct RawJSONView: View {
    let response: ReasoningContentView.ReasoningResponse
    @State private var formattedJSON: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Raw Response", systemImage: "curlybraces")
                .font(.headline)
                .foregroundColor(.blue)
            
            ScrollView(.horizontal) {
                Text(formattedJSON.isEmpty ? formatJSON() : formattedJSON)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            formattedJSON = formatJSON()
        }
    }
    
    private func formatJSON() -> String {
        let data: [String: Any] = [
            "model": response.model,
            "request_id": response.requestId,
            "message": [
                "content": response.answer,
                "reasoning_content": response.reasoning ?? NSNull()
            ],
            "usage": [
                "prompt_tokens": response.tokens.prompt,
                "reasoning_tokens": response.tokens.reasoning,
                "completion_tokens": response.tokens.completion,
                "total_tokens": response.tokens.total
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "Failed to format JSON"
        }
        
        return jsonString
    }
}

// MARK: - Supporting Views

struct FormattedReasoningView: View {
    let content: String
    @State private var sections: [ReasoningSection] = []
    
    struct ReasoningSection: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let type: SectionType
        
        enum SectionType {
            case step(number: Int)
            case thought
            case analysis
            case conclusion
            case general
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(sections) { section in
                ReasoningSectionView(section: section)
            }
        }
        .onAppear {
            parseSections()
        }
    }
    
    private func parseSections() {
        let lines = content.components(separatedBy: .newlines)
        var currentSection: (title: String, content: [String], type: ReasoningSection.SectionType)?
        var parsedSections: [ReasoningSection] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for step headers
            if let stepNumber = extractStepNumber(from: trimmed) {
                if let section = currentSection {
                    parsedSections.append(ReasoningSection(
                        title: section.title,
                        content: section.content.joined(separator: "\n"),
                        type: section.type
                    ))
                }
                currentSection = ("Step \(stepNumber)", [], .step(number: stepNumber))
            }
            // Check for other section headers
            else if trimmed.hasSuffix(":") && trimmed.count < 50 {
                if let section = currentSection {
                    parsedSections.append(ReasoningSection(
                        title: section.title,
                        content: section.content.joined(separator: "\n"),
                        type: section.type
                    ))
                }
                let type = determineSectionType(from: trimmed)
                currentSection = (trimmed, [], type)
            }
            // Add to current section
            else if !trimmed.isEmpty {
                currentSection?.content.append(trimmed)
            }
        }
        
        // Add final section
        if let section = currentSection {
            parsedSections.append(ReasoningSection(
                title: section.title,
                content: section.content.joined(separator: "\n"),
                type: section.type
            ))
        }
        
        sections = parsedSections.isEmpty ? [ReasoningSection(
            title: "Reasoning",
            content: content,
            type: .general
        )] : parsedSections
    }
    
    private func extractStepNumber(from text: String) -> Int? {
        let patterns = [
            "Step (\\d+)",
            "STEP (\\d+)",
            "(\\d+)\\.",
            "(\\d+)\\)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return Int(text[range])
            }
        }
        
        return nil
    }
    
    private func determineSectionType(from header: String) -> ReasoningSection.SectionType {
        let lowercased = header.lowercased()
        
        if lowercased.contains("thought") || lowercased.contains("thinking") {
            return .thought
        } else if lowercased.contains("analysis") || lowercased.contains("analyze") {
            return .analysis
        } else if lowercased.contains("conclusion") || lowercased.contains("therefore") {
            return .conclusion
        }
        
        return .general
    }
}

struct ReasoningSectionView: View {
    let section: FormattedReasoningView.ReasoningSection
    
    var icon: String {
        switch section.type {
        case .step: return "number.circle.fill"
        case .thought: return "lightbulb.fill"
        case .analysis: return "magnifyingglass"
        case .conclusion: return "checkmark.seal.fill"
        case .general: return "text.alignleft"
        }
    }
    
    var color: Color {
        switch section.type {
        case .step: return .blue
        case .thought: return .yellow
        case .analysis: return .purple
        case .conclusion: return .green
        case .general: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(section.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text(section.content)
                .font(.caption)
                .padding()
                .background(color.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct TokenUsageCard: View {
    let tokens: ReasoningContentView.ReasoningResponse.TokenUsage
    
    var body: some View {
        HStack(spacing: 16) {
            TokenStat(label: "Prompt", value: tokens.prompt, color: .blue)
            TokenStat(label: "Reasoning", value: tokens.reasoning, color: .purple)
            TokenStat(label: "Answer", value: tokens.completion, color: .green)
            TokenStat(label: "Total", value: tokens.total, color: .orange)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TokenStat: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Ask a reasoning question")
                .font(.headline)
            
            Text("The DeepSeek reasoner will show its thinking process")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Example Usage

struct ReasoningContentDemo: View {
    let apiKey: String
    @State private var exampleQuestions = [
        "If I have 3 apples and give away half, then buy 5 more, how many do I have?",
        "What's the most efficient sorting algorithm for a nearly sorted array?",
        "Should I invest in stocks or bonds given current market conditions?",
        "How can I optimize this recursive function for better performance?"
    ]
    
    var body: some View {
        ReasoningContentView(apiKey: apiKey)
            .onAppear {
                // Preload with an example question
            }
    }
}