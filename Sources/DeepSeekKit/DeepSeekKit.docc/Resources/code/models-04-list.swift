import SwiftUI
import DeepSeekKit

struct ModelExplorer: View {
    @StateObject private var client = DeepSeekClient()
    @State private var availableModels: [Model] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Available DeepSeek Models")
                .font(.largeTitle)
                .bold()
            
            Button("Fetch Available Models") {
                Task {
                    await fetchModels()
                }
            }
            .disabled(isLoading)
            
            if isLoading {
                ProgressView("Loading models...")
                    .padding()
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if !availableModels.isEmpty {
                List(availableModels) { model in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.id)
                            .font(.headline)
                        
                        HStack {
                            Label("Created", systemImage: "calendar")
                                .font(.caption)
                            Text(Date(timeIntervalSince1970: model.created), style: .date)
                                .font(.caption)
                        }
                        
                        if let ownedBy = model.ownedBy {
                            HStack {
                                Label("Owner", systemImage: "person")
                                    .font(.caption)
                                Text(ownedBy)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            Task {
                await fetchModels()
            }
        }
    }
    
    private func fetchModels() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let modelsResponse = try await client.models()
            availableModels = modelsResponse.data
        } catch {
            errorMessage = "Failed to fetch models: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}