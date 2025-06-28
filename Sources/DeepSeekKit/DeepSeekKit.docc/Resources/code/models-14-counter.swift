import SwiftUI
import DeepSeekKit

struct UsageTracking: View {
    @State private var inputText = ""
    @State private var selectedModel: DeepSeekModel = .chat
    @State private var estimatedTokens = 0
    @State private var estimatedCost = 0.0
    @State private var characterCount = 0
    @State private var wordCount = 0
    
    // Pricing per 1M tokens (example rates - adjust to actual)
    private let pricingRates: [DeepSeekModel: (input: Double, output: Double)] = [
        .chat: (input: 0.14, output: 0.28),
        .reasoner: (input: 0.55, output: 2.19)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Token Counter")
                        .font(.largeTitle)
                        .bold()
                    
                    // Model Selector
                    VStack(alignment: .leading) {
                        Text("Select Model")
                            .font(.headline)
                        
                        Picker("Model", selection: $selectedModel) {
                            Label("Chat ($0.14/1M input)", systemImage: "bubble.left.and.bubble.right")
                                .tag(DeepSeekModel.chat)
                            Label("Reasoner ($0.55/1M input)", systemImage: "brain")
                                .tag(DeepSeekModel.reasoner)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Input Area
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Input Text")
                                .font(.headline)
                            Spacer()
                            Text("\(characterCount) characters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        TextEditor(text: $inputText)
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: inputText) { _ in
                                updateEstimates()
                            }
                    }
                    
                    // Live Statistics
                    VStack(spacing: 15) {
                        StatisticRow(
                            icon: "textformat.size",
                            title: "Words",
                            value: "\(wordCount)",
                            color: .blue
                        )
                        
                        StatisticRow(
                            icon: "number",
                            title: "Estimated Tokens",
                            value: "\(estimatedTokens)",
                            color: .orange
                        )
                        
                        StatisticRow(
                            icon: "dollarsign.circle",
                            title: "Estimated Input Cost",
                            value: String(format: "$%.6f", estimatedCost),
                            color: .green
                        )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Token Estimation Info
                    InfoBox(
                        title: "How Token Estimation Works",
                        items: [
                            "1 token ≈ 4 characters in English",
                            "1 token ≈ ¾ words",
                            "Common words are single tokens",
                            "Complex words may be multiple tokens"
                        ]
                    )
                    
                    // Cost Calculator
                    CostCalculatorView(
                        model: selectedModel,
                        estimatedInputTokens: estimatedTokens,
                        rates: pricingRates[selectedModel] ?? (0, 0)
                    )
                    
                    // Quick Examples
                    VStack(alignment: .leading) {
                        Text("Quick Examples")
                            .font(.headline)
                        
                        ForEach(examples, id: \.text) { example in
                            Button(action: { inputText = example.text }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(example.title)
                                            .font(.subheadline)
                                        Text("~\(example.tokens) tokens")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
            .onAppear {
                updateEstimates()
            }
        }
    }
    
    private func updateEstimates() {
        // Character count
        characterCount = inputText.count
        
        // Word count
        wordCount = inputText.split { $0.isWhitespace || $0.isNewline }.count
        
        // Token estimation (rough approximation)
        // More sophisticated tokenization would use actual tokenizer
        estimatedTokens = estimateTokenCount(inputText)
        
        // Cost estimation
        let rates = pricingRates[selectedModel] ?? (0, 0)
        estimatedCost = Double(estimatedTokens) / 1_000_000 * rates.input
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Simple estimation: ~4 characters per token
        // In practice, you'd use a proper tokenizer
        let baseEstimate = text.count / 4
        
        // Adjust for whitespace and punctuation
        let whitespaceCount = text.filter { $0.isWhitespace }.count
        let punctuationCount = text.filter { $0.isPunctuation }.count
        
        // Refined estimate
        return max(1, baseEstimate - whitespaceCount/4 + punctuationCount/2)
    }
    
    private let examples = [
        (title: "Simple greeting", text: "Hello, how are you today?", tokens: 7),
        (title: "Code snippet", text: "func calculateSum(_ a: Int, _ b: Int) -> Int {\n    return a + b\n}", tokens: 20),
        (title: "Math problem", text: "Solve the quadratic equation: x² + 5x + 6 = 0", tokens: 15),
        (title: "Long prompt", text: "Write a detailed explanation of how machine learning models process natural language, including tokenization, embedding, and attention mechanisms. Provide examples and discuss the implications for AI understanding.", tokens: 45)
    ]
}

struct StatisticRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

struct InfoBox: View {
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Text("•")
                        .foregroundColor(.blue)
                    Text(item)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
}

struct CostCalculatorView: View {
    let model: DeepSeekModel
    let estimatedInputTokens: Int
    let rates: (input: Double, output: Double)
    
    @State private var expectedOutputTokens = 150
    
    private var totalCost: Double {
        let inputCost = Double(estimatedInputTokens) / 1_000_000 * rates.input
        let outputCost = Double(expectedOutputTokens) / 1_000_000 * rates.output
        return inputCost + outputCost
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cost Calculator")
                .font(.headline)
            
            // Expected Output Slider
            VStack(alignment: .leading) {
                HStack {
                    Text("Expected output tokens:")
                    Spacer()
                    Text("\(expectedOutputTokens)")
                        .bold()
                }
                .font(.subheadline)
                
                Slider(value: Binding(
                    get: { Double(expectedOutputTokens) },
                    set: { expectedOutputTokens = Int($0) }
                ), in: 10...2000, step: 10)
            }
            
            // Cost Breakdown
            VStack(spacing: 10) {
                CostRow(
                    label: "Input cost",
                    tokens: estimatedInputTokens,
                    rate: rates.input,
                    cost: Double(estimatedInputTokens) / 1_000_000 * rates.input
                )
                
                CostRow(
                    label: "Output cost",
                    tokens: expectedOutputTokens,
                    rate: rates.output,
                    cost: Double(expectedOutputTokens) / 1_000_000 * rates.output
                )
                
                Divider()
                
                HStack {
                    Text("Total estimated cost")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "$%.6f", totalCost))
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(10)
    }
}

struct CostRow: View {
    let label: String
    let tokens: Int
    let rate: Double
    let cost: Double
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Text("(\(tokens) tokens @ $\(String(format: "%.2f", rate))/1M)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "$%.6f", cost))
                .font(.subheadline)
        }
    }
}