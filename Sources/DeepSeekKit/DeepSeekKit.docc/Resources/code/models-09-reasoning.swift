import SwiftUI
import DeepSeekKit

struct ReasonerExample: View {
    @StateObject private var client = DeepSeekClient()
    @State private var problem = "If a train travels 120 miles in 2 hours, and then travels 180 miles in 3 hours, what is its average speed for the entire journey?"
    @State private var response: ChatResponse?
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Reasoner Model Example")
                    .font(.largeTitle)
                    .bold()
                
                // Problem Input
                VStack(alignment: .leading) {
                    Text("Problem:")
                        .font(.headline)
                    
                    TextEditor(text: $problem)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Button(action: solveWithReasoning) {
                    Label("Solve with Reasoning", systemImage: "brain")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(problem.isEmpty || isLoading)
                
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Thinking through the problem...")
                    }
                    .padding()
                }
                
                // Response Display
                if let response = response,
                   let choice = response.choices.first {
                    
                    // Reasoning Content
                    if let reasoning = choice.message.reasoningContent {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "brain")
                                    .foregroundColor(.purple)
                                Text("Reasoning Process")
                                    .font(.headline)
                            }
                            
                            Text(reasoning)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(10)
                                .font(.callout)
                        }
                    }
                    
                    // Final Answer
                    if let content = choice.message.content {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                Text("Final Answer")
                                    .font(.headline)
                            }
                            
                            Text(content)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    
                    // Usage Statistics
                    if let usage = response.usage {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Token Usage")
                                .font(.headline)
                            
                            HStack {
                                Label("\(usage.promptTokens) prompt", systemImage: "arrow.up")
                                Spacer()
                                Label("\(usage.completionTokens) completion", systemImage: "arrow.down")
                                Spacer()
                                Label("\(usage.totalTokens) total", systemImage: "sum")
                            }
                            .font(.caption)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
    }
    
    private func solveWithReasoning() {
        isLoading = true
        response = nil
        
        Task {
            do {
                // Use the reasoner model to get detailed reasoning
                response = try await client.chat(
                    messages: [.user(problem)],
                    model: .reasoner
                )
            } catch {
                // Handle error by creating a mock response
                response = ChatResponse(
                    id: "error",
                    object: "chat.completion",
                    created: Int(Date().timeIntervalSince1970),
                    model: "deepseek-reasoner",
                    choices: [
                        ChatChoice(
                            index: 0,
                            message: ResponseMessage(
                                role: "assistant",
                                content: "Error: \(error.localizedDescription)"
                            ),
                            finishReason: "error"
                        )
                    ],
                    usage: nil
                )
            }
            
            isLoading = false
        }
    }
}