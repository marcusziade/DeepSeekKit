import SwiftUI
import DeepSeekKit

struct ModelSelector: View {
    @State private var selectedModel: DeepSeekModel = .chat
    @State private var selectedUseCase: UseCase?
    
    enum UseCase: String, CaseIterable {
        case general = "General Conversation"
        case coding = "Code Generation"
        case math = "Mathematical Problems"
        case analysis = "Data Analysis"
        case creative = "Creative Writing"
        case reasoning = "Complex Reasoning"
        
        var recommendedModel: DeepSeekModel {
            switch self {
            case .general, .coding, .creative:
                return .chat
            case .math, .analysis, .reasoning:
                return .reasoner
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "bubble.left.and.bubble.right"
            case .coding: return "chevron.left.forwardslash.chevron.right"
            case .math: return "function"
            case .analysis: return "chart.bar"
            case .creative: return "paintbrush"
            case .reasoning: return "brain"
            }
        }
        
        var description: String {
            switch self {
            case .general: return "Everyday conversations and questions"
            case .coding: return "Writing and explaining code"
            case .math: return "Solving mathematical problems with steps"
            case .analysis: return "Analyzing data and providing insights"
            case .creative: return "Stories, poems, and creative content"
            case .reasoning: return "Complex problems requiring detailed analysis"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current Selection
                HStack {
                    Text("Selected Model:")
                        .font(.headline)
                    Text(selectedModel.rawValue)
                        .font(.headline)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                // Use Case Grid
                Text("Choose your use case:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                    ForEach(UseCase.allCases, id: \.self) { useCase in
                        UseCaseCard(
                            useCase: useCase,
                            isSelected: selectedUseCase == useCase,
                            action: {
                                selectedUseCase = useCase
                                selectedModel = useCase.recommendedModel
                            }
                        )
                    }
                }
                
                // Recommendation
                if let useCase = selectedUseCase {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                            Text("Recommendation")
                                .font(.headline)
                        }
                        
                        Text("For \(useCase.rawValue), we recommend the **\(useCase.recommendedModel.rawValue)** model.")
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Model Use Cases")
        }
    }
}

struct UseCaseCard: View {
    let useCase: ModelSelector.UseCase
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: useCase.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(useCase.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(useCase.description)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}