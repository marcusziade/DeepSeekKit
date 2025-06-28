import SwiftUI
import DeepSeekKit

// Compare chat vs reasoner models
struct ModelComparison: View {
    @StateObject private var chatClient: DeepSeekClient
    @StateObject private var reasonerClient: DeepSeekClient
    @State private var question = "If a train travels 120 miles in 2 hours, then slows down to half its speed for the next 3 hours, how far did it travel in total?"
    @State private var chatResponse: ChatResponse?
    @State private var reasonerResponse: ReasonerResponse?
    @State private var isLoading = false
    
    struct ChatResponse {
        let content: String
        let responseTime: TimeInterval
        let model: String
    }
    
    struct ReasonerResponse {
        let content: String
        let reasoningContent: String?
        let responseTime: TimeInterval
        let model: String
    }
    
    init(apiKey: String) {
        _chatClient = StateObject(wrappedValue: DeepSeekClient(apiKey: apiKey))
        _reasonerClient = StateObject(wrappedValue: DeepSeekClient(apiKey: apiKey))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Question input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Question")
                        .font(.headline)
                    
                    TextEditor(text: $question)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Compare button
                Button(action: compareModels) {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Comparing models...")
                        }
                    } else {
                        Text("Compare Models")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(question.isEmpty || isLoading)
                
                // Results
                HStack(alignment: .top, spacing: 16) {
                    // Chat model result
                    ModelResultCard(
                        title: "Chat Model",
                        subtitle: "Direct answer",
                        response: chatResponse?.content,
                        reasoningContent: nil,
                        responseTime: chatResponse?.responseTime,
                        color: .blue
                    )
                    
                    // Reasoner model result
                    ModelResultCard(
                        title: "Reasoner Model",
                        subtitle: "Step-by-step reasoning",
                        response: reasonerResponse?.content,
                        reasoningContent: reasonerResponse?.reasoningContent,
                        responseTime: reasonerResponse?.responseTime,
                        color: .purple
                    )
                }
                
                // Comparison insights
                if chatResponse != nil && reasonerResponse != nil {
                    ComparisonInsights(
                        chatResponse: chatResponse!,
                        reasonerResponse: reasonerResponse!
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Model Comparison")
    }
    
    private func compareModels() {
        Task {
            await performComparison()
        }
    }
    
    @MainActor
    private func performComparison() async {
        isLoading = true
        chatResponse = nil
        reasonerResponse = nil
        
        // Run both models in parallel
        async let chatTask = runChatModel()
        async let reasonerTask = runReasonerModel()
        
        let (chat, reasoner) = await (chatTask, reasonerTask)
        
        chatResponse = chat
        reasonerResponse = reasoner
        isLoading = false
    }
    
    private func runChatModel() async -> ChatResponse? {
        let startTime = Date()
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: [
                    Message(role: .user, content: question)
                ],
                temperature: 0.3 // Lower temperature for more consistent math
            )
            
            let response = try await chatClient.chat.completions(request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let content = response.choices.first?.message.content {
                return ChatResponse(
                    content: content,
                    responseTime: responseTime,
                    model: response.model
                )
            }
        } catch {
            print("Chat model error: \(error)")
        }
        
        return nil
    }
    
    private func runReasonerModel() async -> ReasonerResponse? {
        let startTime = Date()
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .user, content: question)
                ],
                temperature: 0.3
            )
            
            let response = try await reasonerClient.chat.completions(request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let choice = response.choices.first {
                return ReasonerResponse(
                    content: choice.message.content,
                    reasoningContent: choice.message.reasoningContent,
                    responseTime: responseTime,
                    model: response.model
                )
            }
        } catch {
            print("Reasoner model error: \(error)")
        }
        
        return nil
    }
}

// MARK: - UI Components

struct ModelResultCard: View {
    let title: String
    let subtitle: String
    let response: String?
    let reasoningContent: String?
    let responseTime: TimeInterval?
    let color: Color
    
    @State private var showingReasoning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let time = responseTime {
                    Text(String(format: "%.2fs", time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Response
            if let response = response {
                Text(response)
                    .font(.body)
                    .padding()
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
                
                // Reasoning toggle
                if let reasoning = reasoningContent, !reasoning.isEmpty {
                    Button(action: { showingReasoning.toggle() }) {
                        HStack {
                            Image(systemName: showingReasoning ? "chevron.up" : "chevron.down")
                            Text(showingReasoning ? "Hide Reasoning" : "Show Reasoning")
                            Spacer()
                        }
                        .font(.caption)
                        .foregroundColor(color)
                    }
                    
                    if showingReasoning {
                        ReasoningView(content: reasoning)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ReasoningView: View {
    let content: String
    
    var formattedContent: AttributedString {
        var attributed = AttributedString(content)
        
        // Highlight reasoning steps
        if let range = attributed.range(of: "Step") {
            attributed[range].foregroundColor = .blue
            attributed[range].font = .body.bold()
        }
        
        return attributed
    }
    
    var body: some View {
        ScrollView {
            Text(formattedContent)
                .font(.caption)
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
        }
        .frame(maxHeight: 300)
    }
}

struct ComparisonInsights: View {
    let chatResponse: ModelComparison.ChatResponse
    let reasonerResponse: ModelComparison.ReasonerResponse
    
    var speedDifference: Double {
        reasonerResponse.responseTime / chatResponse.responseTime
    }
    
    var hasDetailedSteps: Bool {
        reasonerResponse.reasoningContent?.contains("Step") ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comparison Insights")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                // Speed comparison
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.orange)
                    
                    Text("The chat model was \(String(format: "%.1fx", speedDifference)) faster")
                        .font(.subheadline)
                }
                
                // Reasoning depth
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    
                    Text(hasDetailedSteps ? 
                         "The reasoner provided step-by-step thinking" : 
                         "The reasoner provided its thought process")
                        .font(.subheadline)
                }
                
                // Use case recommendations
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("When to use each model:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Chat: Quick answers, conversations, simple queries")
                            .font(.caption)
                        Text("• Reasoner: Complex problems, learning, verification")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Demo Examples

struct ModelComparisonDemo: View {
    let apiKey: String
    @State private var selectedExample = 0
    
    let examples = [
        (
            title: "Math Problem",
            question: "If a train travels 120 miles in 2 hours, then slows down to half its speed for the next 3 hours, how far did it travel in total?"
        ),
        (
            title: "Logic Puzzle",
            question: "Three friends - Alice, Bob, and Charlie - each have a different favorite color (red, blue, green). Alice doesn't like red. Bob's favorite color starts with the same letter as his name. What is each person's favorite color?"
        ),
        (
            title: "Code Analysis",
            question: """
            What's wrong with this Swift code and how would you fix it?
            
            func fibonacci(_ n: Int) -> Int {
                if n <= 1 { return n }
                return fibonacci(n - 1) + fibonacci(n - 2)
            }
            
            // Usage
            print(fibonacci(50))
            """
        ),
        (
            title: "Decision Making",
            question: "I have $10,000 to invest. Should I put it all in stocks, bonds, or split it? Consider risk tolerance, time horizon, and current market conditions."
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Example Questions")
                .font(.headline)
            
            Picker("Example", selection: $selectedExample) {
                ForEach(0..<examples.count, id: \.self) { index in
                    Text(examples[index].title).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            ModelComparison(apiKey: apiKey)
                .onAppear {
                    // Set initial question
                }
        }
    }
}