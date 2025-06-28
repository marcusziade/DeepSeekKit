import SwiftUI
import DeepSeekKit

struct ModelExplorer: View {
    // Available models in DeepSeekKit
    let availableModels: [DeepSeekModel] = [
        .chat,
        .reasoner
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("DeepSeek Models")
                .font(.largeTitle)
                .bold()
            
            ForEach(availableModels, id: \.self) { model in
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    Text(model.rawValue)
                        .font(.headline)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}