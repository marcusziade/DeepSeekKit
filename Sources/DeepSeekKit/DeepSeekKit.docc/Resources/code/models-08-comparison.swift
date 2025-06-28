import SwiftUI
import DeepSeekKit

struct ModelSelector: View {
    @StateObject private var client = DeepSeekClient()
    @State private var userPrompt = "Explain how recursion works in programming"
    @State private var chatResponse = ""
    @State private var reasonerResponse = ""
    @State private var reasonerReasoning = ""
    @State private var isLoadingChat = false
    @State private var isLoadingReasoner = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Input Section
                    VStack(alignment: .leading) {
                        Text("Enter your prompt:")
                            .font(.headline)
                        
                        TextEditor(text: $userPrompt)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Button(action: compareModels) {
                            Label("Compare Models", systemImage: "arrow.triangle.branch")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(userPrompt.isEmpty || isLoadingChat || isLoadingReasoner)
                    }
                    
                    // Comparison Results
                    HStack(alignment: .top, spacing: 15) {
                        // Chat Model Response
                        ModelResponseView(
                            title: "Chat Model",
                            icon: "bubble.left.and.bubble.right",
                            response: chatResponse,
                            reasoning: nil,
                            isLoading: isLoadingChat,
                            color: .blue
                        )
                        
                        // Reasoner Model Response
                        ModelResponseView(
                            title: "Reasoner Model",
                            icon: "brain",
                            response: reasonerResponse,
                            reasoning: reasonerReasoning,
                            isLoading: isLoadingReasoner,
                            color: .purple
                        )
                    }
                    
                    // Comparison Insights
                    if !chatResponse.isEmpty && !reasonerResponse.isEmpty {
                        ComparisonInsights(
                            chatResponse: chatResponse,
                            reasonerResponse: reasonerResponse,
                            hasReasoning: !reasonerReasoning.isEmpty
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Model Comparison")
        }
    }
    
    private func compareModels() {
        // Clear previous responses
        chatResponse = ""
        reasonerResponse = ""
        reasonerReasoning = ""
        
        // Query both models in parallel
        Task {
            async let chatTask = queryModel(.chat)
            async let reasonerTask = queryModel(.reasoner)
            
            await chatTask
            await reasonerTask
        }
    }
    
    private func queryModel(_ model: DeepSeekModel) async {
        if model == .chat {
            isLoadingChat = true
        } else {
            isLoadingReasoner = true
        }
        
        do {
            let response = try await client.chat(
                messages: [.user(userPrompt)],
                model: model
            )
            
            if let choice = response.choices.first {
                if model == .chat {
                    chatResponse = choice.message.content ?? ""
                } else {
                    reasonerResponse = choice.message.content ?? ""
                    reasonerReasoning = choice.message.reasoningContent ?? ""
                }
            }
        } catch {
            let errorMessage = "Error: \(error.localizedDescription)"
            if model == .chat {
                chatResponse = errorMessage
            } else {
                reasonerResponse = errorMessage
            }
        }
        
        if model == .chat {
            isLoadingChat = false
        } else {
            isLoadingReasoner = false
        }
    }
}

struct ModelResponseView: View {
    let title: String
    let icon: String
    let response: String
    let reasoning: String?
    let isLoading: Bool
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if !response.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(response)
                            .font(.body)
                        
                        if let reasoning = reasoning, !reasoning.isEmpty {
                            DisclosureGroup("Reasoning Process") {
                                Text(reasoning)
                                    .font(.caption)
                                    .padding(8)
                                    .background(color.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else {
                Text("No response yet")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ComparisonInsights: View {
    let chatResponse: String
    let reasonerResponse: String
    let hasReasoning: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comparison Insights")
                .font(.headline)
            
            HStack {
                Image(systemName: "speedometer")
                Text("Response Length")
                Spacer()
                Text("Chat: \(chatResponse.count) chars")
                Text("|")
                Text("Reasoner: \(reasonerResponse.count) chars")
            }
            .font(.caption)
            
            if hasReasoning {
                HStack {
                    Image(systemName: "brain")
                    Text("The reasoner model provided step-by-step reasoning")
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
            
            HStack {
                Image(systemName: "clock")
                Text("The chat model typically responds faster")
                    .font(.caption)
            }
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
    }
}