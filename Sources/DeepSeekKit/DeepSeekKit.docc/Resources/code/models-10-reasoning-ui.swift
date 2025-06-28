import SwiftUI
import DeepSeekKit

struct ReasonerExample: View {
    @StateObject private var client = DeepSeekClient()
    @State private var problem = ""
    @State private var reasoningSteps: [ReasoningStep] = []
    @State private var finalAnswer = ""
    @State private var isLoading = false
    @State private var showReasoning = true
    
    struct ReasoningStep: Identifiable {
        let id = UUID()
        let content: String
        let stepNumber: Int
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Input Section
                    VStack(alignment: .leading) {
                        Text("Enter a problem:")
                            .font(.headline)
                        
                        TextEditor(text: $problem)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Button(action: analyzeWithReasoning) {
                            Label("Analyze", systemImage: "brain")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(problem.isEmpty || isLoading)
                    }
                    
                    if isLoading {
                        ReasoningLoadingView()
                    }
                    
                    // Results Section
                    if !reasoningSteps.isEmpty || !finalAnswer.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            // Toggle for showing/hiding reasoning
                            Toggle(isOn: $showReasoning) {
                                Label("Show Reasoning Process", systemImage: "brain")
                                    .font(.headline)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                            
                            // Reasoning Steps
                            if showReasoning && !reasoningSteps.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Thinking Process")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                    
                                    ForEach(reasoningSteps) { step in
                                        ReasoningStepView(step: step)
                                    }
                                }
                            }
                            
                            // Final Answer
                            if !finalAnswer.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                        Text("Final Answer")
                                            .font(.headline)
                                    }
                                    
                                    Text(finalAnswer)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Reasoning UI Demo")
        }
    }
    
    private func analyzeWithReasoning() {
        isLoading = true
        reasoningSteps = []
        finalAnswer = ""
        
        Task {
            do {
                let response = try await client.chat(
                    messages: [.user(problem)],
                    model: .reasoner
                )
                
                if let choice = response.choices.first {
                    // Parse reasoning content into steps
                    if let reasoning = choice.message.reasoningContent {
                        reasoningSteps = parseReasoningSteps(reasoning)
                    }
                    
                    // Set final answer
                    finalAnswer = choice.message.content ?? ""
                }
            } catch {
                finalAnswer = "Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func parseReasoningSteps(_ reasoning: String) -> [ReasoningStep] {
        // Split reasoning into logical steps
        let lines = reasoning.split(separator: "\n")
        var steps: [ReasoningStep] = []
        var currentStep = ""
        var stepNumber = 1
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Detect step boundaries (lines starting with numbers, "First", "Next", etc.)
            if trimmedLine.first?.isNumber == true ||
               trimmedLine.hasPrefix("First") ||
               trimmedLine.hasPrefix("Next") ||
               trimmedLine.hasPrefix("Then") ||
               trimmedLine.hasPrefix("Finally") {
                
                if !currentStep.isEmpty {
                    steps.append(ReasoningStep(content: currentStep, stepNumber: stepNumber))
                    stepNumber += 1
                    currentStep = ""
                }
            }
            
            currentStep += trimmedLine + "\n"
        }
        
        // Add the last step
        if !currentStep.isEmpty {
            steps.append(ReasoningStep(content: currentStep, stepNumber: stepNumber))
        }
        
        // If no clear steps were found, treat the whole reasoning as one step
        if steps.isEmpty && !reasoning.isEmpty {
            steps.append(ReasoningStep(content: reasoning, stepNumber: 1))
        }
        
        return steps
    }
}

struct ReasoningStepView: View {
    let step: ReasonerExample.ReasoningStep
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text("\(step.stepNumber)")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                    
                    Text("Step \(step.stepNumber)")
                        .font(.subheadline)
                        .bold()
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(step.content)
                    .font(.callout)
                    .padding(.leading, 38)
                    .padding(.trailing, 8)
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(10)
    }
}

struct ReasoningLoadingView: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
                        .scaleEffect(animationAmount)
                        .opacity(2 - animationAmount)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.5),
                            value: animationAmount
                        )
                }
                
                Image(systemName: "brain")
                    .font(.title)
                    .foregroundColor(.purple)
            }
            
            Text("Analyzing and reasoning...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            animationAmount = 2
        }
    }
}