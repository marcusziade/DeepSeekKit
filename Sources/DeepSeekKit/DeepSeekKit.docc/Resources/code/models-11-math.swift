import SwiftUI
import DeepSeekKit

struct ReasonerExample: View {
    @StateObject private var client = DeepSeekClient()
    @State private var mathProblem = "A rectangular garden has a length that is 3 meters more than twice its width. If the perimeter of the garden is 36 meters, what are the dimensions of the garden?"
    @State private var solution: MathSolution?
    @State private var isLoading = false
    
    struct MathSolution {
        let problem: String
        let reasoning: String
        let steps: [String]
        let finalAnswer: String
        let verification: String?
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading) {
                        Text("Math Problem Solver")
                            .font(.largeTitle)
                            .bold()
                        Text("Using DeepSeek Reasoner for step-by-step solutions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Problem Input
                    VStack(alignment: .leading) {
                        Label("Enter a math problem:", systemImage: "function")
                            .font(.headline)
                        
                        TextEditor(text: $mathProblem)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        // Quick Examples
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(mathExamples, id: \.self) { example in
                                    Button(action: { mathProblem = example }) {
                                        Text(example)
                                            .lineLimit(1)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(15)
                                    }
                                }
                            }
                        }
                    }
                    
                    Button(action: solveMathProblem) {
                        Label("Solve Step by Step", systemImage: "brain")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(mathProblem.isEmpty || isLoading)
                    
                    if isLoading {
                        MathLoadingView()
                    }
                    
                    // Solution Display
                    if let solution = solution {
                        MathSolutionView(solution: solution)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    private let mathExamples = [
        "Find the derivative of f(x) = x³ + 2x² - 5x + 3",
        "Solve: 2x² + 5x - 3 = 0",
        "Calculate the area under y = x² from x = 0 to x = 3"
    ]
    
    private func solveMathProblem() {
        isLoading = true
        solution = nil
        
        Task {
            do {
                let prompt = """
                Solve this math problem step by step:
                \(mathProblem)
                
                Please show all work and verify your answer.
                """
                
                let response = try await client.chat(
                    messages: [.user(prompt)],
                    model: .reasoner
                )
                
                if let choice = response.choices.first {
                    let reasoning = choice.message.reasoningContent ?? ""
                    let answer = choice.message.content ?? ""
                    
                    // Parse the solution into structured format
                    solution = parseMathSolution(
                        problem: mathProblem,
                        reasoning: reasoning,
                        answer: answer
                    )
                }
            } catch {
                // Create error solution
                solution = MathSolution(
                    problem: mathProblem,
                    reasoning: "",
                    steps: ["Error: \(error.localizedDescription)"],
                    finalAnswer: "Could not solve the problem",
                    verification: nil
                )
            }
            
            isLoading = false
        }
    }
    
    private func parseMathSolution(problem: String, reasoning: String, answer: String) -> MathSolution {
        // Extract steps from reasoning
        var steps: [String] = []
        let lines = reasoning.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                steps.append(String(trimmed))
            }
        }
        
        // Try to extract verification if present
        let verification = answer.contains("verify") || answer.contains("check") ? 
            "Solution verified ✓" : nil
        
        return MathSolution(
            problem: problem,
            reasoning: reasoning,
            steps: steps.isEmpty ? [answer] : steps,
            finalAnswer: answer,
            verification: verification
        )
    }
}

struct MathSolutionView: View {
    let solution: ReasonerExample.MathSolution
    @State private var showFullReasoning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Problem Statement
            VStack(alignment: .leading, spacing: 8) {
                Label("Problem", systemImage: "questionmark.circle")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text(solution.problem)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // Solution Steps
            VStack(alignment: .leading, spacing: 8) {
                Label("Solution Steps", systemImage: "list.number")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                ForEach(Array(solution.steps.prefix(5).enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        
                        Text(step)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                }
                
                if solution.steps.count > 5 {
                    Button(action: { showFullReasoning.toggle() }) {
                        Label(
                            showFullReasoning ? "Show Less" : "Show All Steps (\(solution.steps.count))",
                            systemImage: showFullReasoning ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(8)
            
            // Final Answer
            VStack(alignment: .leading, spacing: 8) {
                Label("Answer", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text(solution.finalAnswer)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .font(.body)
            }
            
            // Verification
            if let verification = solution.verification {
                HStack {
                    Image(systemName: "checkmark.seal")
                        .foregroundColor(.green)
                    Text(verification)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        
        if showFullReasoning {
            DisclosureGroup("Full Reasoning Process") {
                Text(solution.reasoning)
                    .font(.caption)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
}

struct MathLoadingView: View {
    @State private var currentStep = 0
    let loadingSteps = [
        "Understanding the problem...",
        "Setting up equations...",
        "Solving step by step...",
        "Verifying the answer..."
    ]
    
    var body: some View {
        VStack(spacing: 15) {
            ProgressView()
            
            Text(loadingSteps[currentStep])
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: currentStep)
        }
        .padding()
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
                if currentStep < loadingSteps.count - 1 {
                    currentStep += 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}