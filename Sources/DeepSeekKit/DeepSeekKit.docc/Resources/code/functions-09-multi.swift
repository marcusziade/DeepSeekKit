import SwiftUI
import DeepSeekKit

// Multi-function workflows
class MultiFunctionWorkflow: ObservableObject {
    @Published var workflowSteps: [WorkflowStep] = []
    @Published var isRunning = false
    @Published var currentStepIndex = -1
    
    private let client: DeepSeekClient
    
    struct WorkflowStep: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let functionCall: FunctionCall?
        var status: Status = .pending
        var result: String?
        var error: Error?
        
        enum Status {
            case pending
            case running
            case completed
            case failed
            
            var color: Color {
                switch self {
                case .pending: return .gray
                case .running: return .orange
                case .completed: return .green
                case .failed: return .red
                }
            }
            
            var icon: String {
                switch self {
                case .pending: return "circle"
                case .running: return "circle.fill"
                case .completed: return "checkmark.circle.fill"
                case .failed: return "xmark.circle.fill"
                }
            }
        }
        
        struct FunctionCall {
            let name: String
            let arguments: [String: Any]
        }
    }
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
    }
    
    // MARK: - Workflow Templates
    
    func loadTravelPlanningWorkflow() {
        workflowSteps = [
            WorkflowStep(
                name: "Check Weather",
                description: "Get weather forecast for destination",
                functionCall: WorkflowStep.FunctionCall(
                    name: "get_weather_forecast",
                    arguments: ["location": "Paris, France", "days": 7]
                )
            ),
            WorkflowStep(
                name: "Find Flights",
                description: "Search for available flights",
                functionCall: WorkflowStep.FunctionCall(
                    name: "search_flights",
                    arguments: [
                        "from": "San Francisco",
                        "to": "Paris",
                        "departure_date": "2024-06-15",
                        "return_date": "2024-06-22"
                    ]
                )
            ),
            WorkflowStep(
                name: "Book Hotel",
                description: "Find and book accommodation",
                functionCall: WorkflowStep.FunctionCall(
                    name: "search_hotels",
                    arguments: [
                        "location": "Paris",
                        "check_in": "2024-06-15",
                        "check_out": "2024-06-22",
                        "guests": 2
                    ]
                )
            ),
            WorkflowStep(
                name: "Plan Activities",
                description: "Suggest activities based on weather",
                functionCall: WorkflowStep.FunctionCall(
                    name: "suggest_activities",
                    arguments: [
                        "location": "Paris",
                        "interests": ["culture", "food", "history"],
                        "weather_dependent": true
                    ]
                )
            ),
            WorkflowStep(
                name: "Create Itinerary",
                description: "Compile all information into travel plan",
                functionCall: nil // This will use AI to synthesize previous results
            )
        ]
    }
    
    func loadDataAnalysisWorkflow() {
        workflowSteps = [
            WorkflowStep(
                name: "Load Data",
                description: "Load dataset from source",
                functionCall: WorkflowStep.FunctionCall(
                    name: "load_data",
                    arguments: ["source": "sales_data.csv", "format": "csv"]
                )
            ),
            WorkflowStep(
                name: "Clean Data",
                description: "Remove duplicates and handle missing values",
                functionCall: WorkflowStep.FunctionCall(
                    name: "clean_data",
                    arguments: ["remove_duplicates": true, "fill_missing": "mean"]
                )
            ),
            WorkflowStep(
                name: "Analyze Trends",
                description: "Perform statistical analysis",
                functionCall: WorkflowStep.FunctionCall(
                    name: "analyze_data",
                    arguments: ["metrics": ["mean", "trend", "seasonality"]]
                )
            ),
            WorkflowStep(
                name: "Generate Visualizations",
                description: "Create charts and graphs",
                functionCall: WorkflowStep.FunctionCall(
                    name: "create_charts",
                    arguments: ["types": ["line", "bar", "heatmap"]]
                )
            ),
            WorkflowStep(
                name: "Generate Report",
                description: "Create comprehensive analysis report",
                functionCall: nil
            )
        ]
    }
    
    func loadContentCreationWorkflow() {
        workflowSteps = [
            WorkflowStep(
                name: "Research Topic",
                description: "Gather information on the topic",
                functionCall: WorkflowStep.FunctionCall(
                    name: "search_web",
                    arguments: ["query": "latest AI trends 2024", "max_results": 10]
                )
            ),
            WorkflowStep(
                name: "Analyze Sources",
                description: "Extract key points from research",
                functionCall: WorkflowStep.FunctionCall(
                    name: "summarize_content",
                    arguments: ["extract_key_points": true, "max_points": 5]
                )
            ),
            WorkflowStep(
                name: "Generate Outline",
                description: "Create article structure",
                functionCall: nil
            ),
            WorkflowStep(
                name: "Write Draft",
                description: "Generate initial content",
                functionCall: nil
            ),
            WorkflowStep(
                name: "Optimize SEO",
                description: "Add keywords and meta description",
                functionCall: WorkflowStep.FunctionCall(
                    name: "seo_optimize",
                    arguments: ["target_keywords": ["AI", "machine learning", "2024"]]
                )
            )
        ]
    }
    
    // MARK: - Workflow Execution
    
    @MainActor
    func executeWorkflow() async {
        isRunning = true
        currentStepIndex = 0
        
        // Reset all steps
        for i in workflowSteps.indices {
            workflowSteps[i].status = .pending
            workflowSteps[i].result = nil
            workflowSteps[i].error = nil
        }
        
        // Execute each step
        for (index, step) in workflowSteps.enumerated() {
            currentStepIndex = index
            workflowSteps[index].status = .running
            
            do {
                let result = await executeStep(step, previousResults: getPreviousResults(upTo: index))
                workflowSteps[index].result = result
                workflowSteps[index].status = .completed
            } catch {
                workflowSteps[index].error = error
                workflowSteps[index].status = .failed
                // Continue with remaining steps or stop based on configuration
                break
            }
            
            // Add delay for demo purposes
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        isRunning = false
        currentStepIndex = -1
    }
    
    private func executeStep(_ step: WorkflowStep, previousResults: [String]) async -> String {
        if let functionCall = step.functionCall {
            // Execute the function
            return await executeFunctionCall(functionCall)
        } else {
            // Use AI to process based on previous results
            return await synthesizeWithAI(step: step, previousResults: previousResults)
        }
    }
    
    private func executeFunctionCall(_ call: WorkflowStep.FunctionCall) async -> String {
        // Simulate function execution
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return mock results based on function name
        switch call.name {
        case "get_weather_forecast":
            return """
            {
                "location": "Paris, France",
                "forecast": [
                    {"date": "2024-06-15", "high": 75, "low": 60, "condition": "Partly Cloudy"},
                    {"date": "2024-06-16", "high": 78, "low": 62, "condition": "Sunny"},
                    {"date": "2024-06-17", "high": 73, "low": 58, "condition": "Light Rain"}
                ]
            }
            """
            
        case "search_flights":
            return """
            {
                "flights": [
                    {"airline": "Air France", "price": 850, "duration": "11h 30m"},
                    {"airline": "United", "price": 920, "duration": "13h 15m"}
                ]
            }
            """
            
        case "search_hotels":
            return """
            {
                "hotels": [
                    {"name": "Hotel Lumière", "price_per_night": 180, "rating": 4.5},
                    {"name": "Le Marais Boutique", "price_per_night": 220, "rating": 4.8}
                ]
            }
            """
            
        default:
            return """
            {
                "status": "completed",
                "message": "Function \(call.name) executed successfully"
            }
            """
        }
    }
    
    private func synthesizeWithAI(step: WorkflowStep, previousResults: [String]) async -> String {
        let systemPrompt = """
        You are executing step '\(step.name)' in a workflow.
        Previous results from the workflow are provided below.
        Synthesize these results to complete the current step: \(step.description)
        """
        
        let userPrompt = """
        Previous workflow results:
        \(previousResults.enumerated().map { "Step \($0.offset + 1): \($0.element)" }.joined(separator: "\n\n"))
        
        Please complete the current step: \(step.description)
        """
        
        do {
            let messages = [
                Message(role: .system, content: systemPrompt),
                Message(role: .user, content: userPrompt)
            ]
            
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: messages,
                temperature: 0.7
            )
            
            let response = try await client.chat.completions(request)
            return response.choices.first?.message.content ?? "No response generated"
        } catch {
            throw error
        }
    }
    
    private func getPreviousResults(upTo index: Int) -> [String] {
        workflowSteps.prefix(index).compactMap { $0.result }
    }
}

// MARK: - UI Components

struct MultiFunctionWorkflowView: View {
    @StateObject private var workflow: MultiFunctionWorkflow
    @State private var selectedTemplate = 0
    
    let templates = [
        "Travel Planning",
        "Data Analysis",
        "Content Creation"
    ]
    
    init(apiKey: String) {
        _workflow = StateObject(wrappedValue: MultiFunctionWorkflow(apiKey: apiKey))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Template selector
            VStack(alignment: .leading) {
                Text("Select Workflow Template")
                    .font(.headline)
                
                Picker("Template", selection: $selectedTemplate) {
                    ForEach(0..<templates.count, id: \.self) { index in
                        Text(templates[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedTemplate) { _ in
                    loadSelectedTemplate()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Workflow visualization
            WorkflowVisualization(
                steps: workflow.workflowSteps,
                currentStepIndex: workflow.currentStepIndex
            )
            
            // Execution button
            Button(action: {
                Task {
                    await workflow.executeWorkflow()
                }
            }) {
                if workflow.isRunning {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text("Running Workflow...")
                    }
                } else {
                    Text("Execute Workflow")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(workflow.isRunning || workflow.workflowSteps.isEmpty)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Multi-Function Workflows")
        .onAppear {
            loadSelectedTemplate()
        }
    }
    
    private func loadSelectedTemplate() {
        switch selectedTemplate {
        case 0:
            workflow.loadTravelPlanningWorkflow()
        case 1:
            workflow.loadDataAnalysisWorkflow()
        case 2:
            workflow.loadContentCreationWorkflow()
        default:
            break
        }
    }
}

struct WorkflowVisualization: View {
    let steps: [MultiFunctionWorkflow.WorkflowStep]
    let currentStepIndex: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    WorkflowStepView(
                        step: step,
                        isActive: index == currentStepIndex,
                        stepNumber: index + 1
                    )
                    
                    if index < steps.count - 1 {
                        WorkflowConnector(
                            isActive: index < currentStepIndex,
                            isNext: index == currentStepIndex
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WorkflowStepView: View {
    let step: MultiFunctionWorkflow.WorkflowStep
    let isActive: Bool
    let stepNumber: Int
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Step number and status
                ZStack {
                    Circle()
                        .fill(step.status.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    if step.status == .running {
                        Circle()
                            .stroke(step.status.color, lineWidth: 3)
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(isActive ? 360 : 0))
                            .animation(
                                Animation.linear(duration: 1)
                                    .repeatForever(autoreverses: false),
                                value: isActive
                            )
                    }
                    
                    Image(systemName: step.status.icon)
                        .foregroundColor(step.status.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(stepNumber): \(step.name)")
                        .font(.headline)
                    
                    Text(step.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let functionCall = step.functionCall {
                        HStack {
                            Image(systemName: "function")
                                .font(.caption)
                            Text(functionCall.name)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                if step.result != nil || step.error != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let result = step.result {
                        Text("Result:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(formatResult(result))
                            .font(.caption)
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if let error = step.error {
                        Text("Error:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        Text(error.localizedDescription)
                            .font(.caption)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(isActive ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut, value: isActive)
    }
    
    private func formatResult(_ result: String) -> String {
        // Try to format as JSON
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let formatted = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let string = String(data: formatted, encoding: .utf8) {
            return string
        }
        
        // Return first 200 characters if not JSON
        return String(result.prefix(200)) + (result.count > 200 ? "..." : "")
    }
}

struct WorkflowConnector: View {
    let isActive: Bool
    let isNext: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isActive ? Color.green : (isNext ? Color.orange : Color.gray.opacity(0.3)))
                .frame(width: 2, height: 30)
                .overlay(
                    GeometryReader { geometry in
                        if isNext {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                                .position(x: geometry.size.width / 2, y: 0)
                                .offset(y: animationOffset)
                                .animation(
                                    Animation.linear(duration: 1)
                                        .repeatForever(autoreverses: false),
                                    value: animationOffset
                                )
                        }
                    }
                )
        }
        .padding(.horizontal, 28)
    }
    
    @State private var animationOffset: CGFloat = 0
    
    var body_: some View {
        onAppear {
            if isNext {
                animationOffset = 30
            }
        }
    }
}

// MARK: - Workflow Builder

struct WorkflowBuilderView: View {
    @State private var workflowName = ""
    @State private var steps: [MultiFunctionWorkflow.WorkflowStep] = []
    @State private var showingAddStep = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Workflow name
            TextField("Workflow Name", text: $workflowName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Steps list
            VStack(alignment: .leading) {
                HStack {
                    Text("Workflow Steps")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { showingAddStep = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
                
                if steps.isEmpty {
                    Text("No steps added yet")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        HStack {
                            Text("\(index + 1). \(step.name)")
                            Spacer()
                            Button(action: {
                                steps.remove(at: index)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Workflow Builder")
        .sheet(isPresented: $showingAddStep) {
            AddWorkflowStepView { step in
                steps.append(step)
            }
        }
    }
}

struct AddWorkflowStepView: View {
    let onAdd: (MultiFunctionWorkflow.WorkflowStep) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var stepName = ""
    @State private var stepDescription = ""
    @State private var useFunction = false
    @State private var functionName = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Step Name", text: $stepName)
                TextField("Description", text: $stepDescription)
                
                Toggle("Use Function Call", isOn: $useFunction)
                
                if useFunction {
                    TextField("Function Name", text: $functionName)
                }
            }
            .navigationTitle("Add Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let step = MultiFunctionWorkflow.WorkflowStep(
                            name: stepName,
                            description: stepDescription,
                            functionCall: useFunction ? MultiFunctionWorkflow.WorkflowStep.FunctionCall(
                                name: functionName,
                                arguments: [:]
                            ) : nil
                        )
                        onAdd(step)
                        dismiss()
                    }
                    .disabled(stepName.isEmpty)
                }
            }
        }
    }
}