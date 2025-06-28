import SwiftUI
import DeepSeekKit

// Understanding the function calling workflow
struct FunctionCallingWorkflow: View {
    @State private var workflowSteps: [WorkflowStep] = []
    @State private var currentStep = 0
    
    struct WorkflowStep {
        let title: String
        let description: String
        let code: String
        let icon: String
    }
    
    let steps = [
        WorkflowStep(
            title: "1. Define Function Tools",
            description: "Describe functions the AI can call",
            code: """
            let weatherTool = ChatCompletionRequest.Tool(
                type: .function,
                function: .init(
                    name: "get_weather",
                    description: "Get current weather",
                    parameters: [
                        "location": ["type": "string"]
                    ]
                )
            )
            """,
            icon: "function"
        ),
        WorkflowStep(
            title: "2. Send Request with Tools",
            description: "Include tools in your chat request",
            code: """
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: messages,
                tools: [weatherTool]
            )
            """,
            icon: "paperplane"
        ),
        WorkflowStep(
            title: "3. AI Decides to Call Function",
            description: "AI determines if a function call is needed",
            code: """
            // AI responds with:
            response.choices.first?.message.toolCalls = [
                ToolCall(
                    id: "call_123",
                    function: Function(
                        name: "get_weather",
                        arguments: "{\\"location\\": \\"San Francisco\\"}"
                    )
                )
            ]
            """,
            icon: "cpu"
        ),
        WorkflowStep(
            title: "4. Execute Function Locally",
            description: "Your code runs the function",
            code: """
            func getWeather(location: String) -> String {
                // Your implementation
                return "72°F, Sunny"
            }
            
            let result = getWeather(location: "San Francisco")
            """,
            icon: "play.circle"
        ),
        WorkflowStep(
            title: "5. Send Results Back",
            description: "Return function results to the AI",
            code: """
            let functionMessage = Message(
                role: .function,
                content: result,
                name: "get_weather"
            )
            
            messages.append(functionMessage)
            """,
            icon: "arrow.uturn.left"
        ),
        WorkflowStep(
            title: "6. AI Uses Results",
            description: "AI incorporates results in its response",
            code: """
            // AI final response:
            "The current weather in San Francisco is 72°F and sunny.
             It's a perfect day for outdoor activities!"
            """,
            icon: "checkmark.circle"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressIndicator(currentStep: currentStep, totalSteps: steps.count)
                .padding()
            
            // Current step
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if currentStep < steps.count {
                        let step = steps[currentStep]
                        
                        HStack {
                            Image(systemName: step.icon)
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(step.title)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(step.description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Code example
                        CodeBlockView(code: step.code)
                        
                        // Explanation
                        ExplanationView(for: currentStep)
                    }
                }
                .padding()
            }
            
            // Navigation
            HStack {
                Button(action: previousStep) {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(currentStep == 0)
                
                Spacer()
                
                Text("Step \(currentStep + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: nextStep) {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(currentStep >= steps.count - 1)
            }
            .padding()
        }
        .navigationTitle("Function Calling Workflow")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func nextStep() {
        withAnimation {
            currentStep = min(currentStep + 1, steps.count - 1)
        }
    }
    
    private func previousStep() {
        withAnimation {
            currentStep = max(currentStep - 1, 0)
        }
    }
}

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                if index < totalSteps - 1 {
                    Rectangle()
                        .fill(index < currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }
}

struct CodeBlockView: View {
    let code: String
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .trailing) {
            Button(action: copyCode) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.trailing, 8)
            
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private func copyCode() {
        UIPasteboard.general.string = code
        isCopied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

struct ExplanationView: View {
    let step: Int
    
    var explanations: [String] = [
        "Function tools tell the AI what functions are available and how to use them. Each tool needs a name, description, and parameter schema.",
        "Include the tools array in your request. The AI will consider these tools when formulating its response.",
        "When the AI determines a function call would help answer the user's question, it responds with tool_calls instead of a regular message.",
        "Parse the function name and arguments from the AI's response, then execute your local function with those arguments.",
        "Create a function message with the results. This tells the AI what your function returned.",
        "The AI processes the function results and generates a natural language response incorporating the information."
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How it works", systemImage: "info.circle")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text(explanations[step])
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
        }
    }
}

// Demo view showing the complete flow
struct FunctionCallingDemo: View {
    @StateObject private var client = DeepSeekClient(
        apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
    )
    @State private var messages: [Message] = []
    @State private var isProcessing = false
    @State private var flowLog: [String] = []
    
    var body: some View {
        VStack {
            // Flow log
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(flowLog, id: \.self) { log in
                        HStack {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                            Text(log)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .frame(height: 200)
            .background(Color(.systemGray6))
            
            Spacer()
            
            // Demo button
            Button(action: runDemo) {
                if isProcessing {
                    ProgressView()
                } else {
                    Text("Run Function Calling Demo")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
        }
        .padding()
    }
    
    private func runDemo() {
        Task {
            await performFunctionCallingDemo()
        }
    }
    
    @MainActor
    private func performFunctionCallingDemo() async {
        isProcessing = true
        flowLog.removeAll()
        
        do {
            // Step 1: Setup
            flowLog.append("🔧 Setting up function tools...")
            let weatherTool = ChatCompletionRequest.Tool(
                type: .function,
                function: ChatCompletionRequest.Tool.Function(
                    name: "get_weather",
                    description: "Get the current weather in a given location",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "location": [
                                "type": "string",
                                "description": "The city and state, e.g. San Francisco, CA"
                            ]
                        ],
                        "required": ["location"]
                    ]
                )
            )
            
            // Step 2: User message
            flowLog.append("💬 User asks: 'What's the weather in San Francisco?'")
            messages = [
                Message(role: .user, content: "What's the weather in San Francisco?")
            ]
            
            // Step 3: Send request
            flowLog.append("📤 Sending request with function tools...")
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: messages,
                tools: [weatherTool]
            )
            
            let response = try await client.chat.completions(request)
            
            // Step 4: Check for function call
            if let toolCalls = response.choices.first?.message.toolCalls {
                flowLog.append("🤖 AI decided to call function: \(toolCalls.first?.function.name ?? "")")
                
                // Step 5: Execute function
                flowLog.append("⚡ Executing function locally...")
                let result = "72°F, Sunny with light clouds"
                
                // Step 6: Send result back
                flowLog.append("📥 Sending function result back to AI...")
                messages.append(Message(
                    role: .function,
                    content: result,
                    name: "get_weather"
                ))
                
                // Step 7: Get final response
                let finalRequest = ChatCompletionRequest(
                    model: .deepSeekChat,
                    messages: messages
                )
                
                let finalResponse = try await client.chat.completions(finalRequest)
                flowLog.append("✅ AI final response: \(finalResponse.choices.first?.message.content ?? "")")
            }
        } catch {
            flowLog.append("❌ Error: \(error.localizedDescription)")
        }
        
        isProcessing = false
    }
}