import SwiftUI
import DeepSeekKit

struct ModelExplorer: View {
    @StateObject private var client = DeepSeekClient()
    @State private var problem = "What is the derivative of x^3 + 2x^2 - 5x + 3?"
    @State private var response = ""
    @State private var reasoning = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("DeepSeek Reasoner Model")
                .font(.largeTitle)
                .bold()
            
            Text("Complex reasoning with step-by-step explanations")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("Enter a complex problem...", text: $problem)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Solve") {
                    Task {
                        await solveWithReasoner()
                    }
                }
                .disabled(problem.isEmpty || isLoading)
            }
            
            if isLoading {
                ProgressView("Thinking...")
                    .padding()
            }
            
            if !reasoning.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reasoning Process:")
                        .font(.headline)
                    Text(reasoning)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if !response.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Final Answer:")
                        .font(.headline)
                    Text(response)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func solveWithReasoner() async {
        isLoading = true
        response = ""
        reasoning = ""
        
        do {
            let chatResponse = try await client.chat(
                messages: [.user(problem)],
                model: .reasoner // Using the reasoner model
            )
            
            if let choice = chatResponse.choices.first {
                response = choice.message.content ?? ""
                reasoning = choice.message.reasoningContent ?? "No reasoning provided"
            }
        } catch {
            response = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}