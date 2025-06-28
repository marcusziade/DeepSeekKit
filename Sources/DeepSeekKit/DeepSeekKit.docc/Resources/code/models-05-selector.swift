import SwiftUI
import DeepSeekKit

struct ModelSelector: View {
    @State private var selectedModel: DeepSeekModel = .chat
    @State private var userInput = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Model Selection
                VStack(alignment: .leading) {
                    Text("Select a Model")
                        .font(.headline)
                    
                    Picker("Model", selection: $selectedModel) {
                        Text("Chat Model").tag(DeepSeekModel.chat)
                        Text("Reasoner Model").tag(DeepSeekModel.reasoner)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Model Description
                VStack(alignment: .leading, spacing: 10) {
                    Text("Model Details")
                        .font(.headline)
                    
                    ModelInfoCard(model: selectedModel)
                }
                
                // Input Area
                VStack(alignment: .leading) {
                    Text("Try it out")
                        .font(.headline)
                    
                    TextEditor(text: $userInput)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Button(action: {
                        // Action will be implemented in next steps
                    }) {
                        Label("Send with \(selectedModel.rawValue)", systemImage: "paperplane")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userInput.isEmpty)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Model Explorer")
        }
    }
}

struct ModelInfoCard: View {
    let model: DeepSeekModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: model == .chat ? "bubble.left.and.bubble.right" : "brain")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(model.rawValue)
                    .font(.title3)
                    .bold()
            }
            
            Text(modelDescription)
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Label("Speed", systemImage: "speedometer")
                    .font(.caption)
                Text(model == .chat ? "Fast" : "Moderate")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
                
                Label("Best for", systemImage: "star")
                    .font(.caption)
                Text(model == .chat ? "General tasks" : "Complex reasoning")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var modelDescription: String {
        switch model {
        case .chat:
            return "Optimized for quick responses and general conversations. Great for most everyday tasks."
        case .reasoner:
            return "Specialized in complex problem-solving with detailed reasoning steps. Ideal for analytical tasks."
        }
    }
}