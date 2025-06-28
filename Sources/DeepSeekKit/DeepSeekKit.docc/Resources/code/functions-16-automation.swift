import SwiftUI
import DeepSeekKit
import Combine

// AI-powered automation suggestions for smart home
class SmartAutomationEngine: ObservableObject {
    @Published var automations: [SmartAutomation] = []
    @Published var suggestions: [AutomationSuggestion] = []
    @Published var usagePatterns: [UsagePattern] = []
    @Published var isAnalyzing = false
    
    private let client: DeepSeekClient
    private let deviceManager: SmartHomeManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Models
    
    struct SmartAutomation: Identifiable, Codable {
        let id = UUID()
        let name: String
        let description: String
        let trigger: Trigger
        let conditions: [Condition]
        let actions: [Action]
        var isEnabled: Bool
        let createdBy: CreationType
        var executionCount: Int = 0
        var lastExecuted: Date?
        var effectiveness: Double = 1.0
        
        enum CreationType: String, Codable {
            case user = "User Created"
            case ai = "AI Suggested"
            case learned = "Learned from Usage"
        }
        
        struct Trigger: Codable {
            let type: TriggerType
            let value: String
            
            enum TriggerType: String, Codable {
                case time = "Time"
                case deviceState = "Device State"
                case location = "Location"
                case weather = "Weather"
                case motion = "Motion"
                case voice = "Voice Command"
            }
        }
        
        struct Condition: Codable {
            let type: ConditionType
            let value: String
            let comparison: Comparison
            
            enum ConditionType: String, Codable {
                case timeRange = "Time Range"
                case dayOfWeek = "Day of Week"
                case deviceState = "Device State"
                case temperature = "Temperature"
                case presence = "Presence"
            }
            
            enum Comparison: String, Codable {
                case equals = "="
                case notEquals = "!="
                case greaterThan = ">"
                case lessThan = "<"
                case contains = "contains"
            }
        }
        
        struct Action: Codable {
            let deviceId: String
            let command: String
            let parameters: [String: String]
            let delay: TimeInterval?
        }
    }
    
    struct AutomationSuggestion: Identifiable {
        let id = UUID()
        let automation: SmartAutomation
        let reason: String
        let confidence: Double
        let potentialSavings: Savings?
        
        struct Savings {
            let energy: Double // kWh
            let cost: Double // $
            let comfort: Double // 0-1 scale
        }
    }
    
    struct UsagePattern: Identifiable {
        let id = UUID()
        let pattern: String
        let frequency: Int
        let timeRange: DateInterval
        let devices: [String]
        let confidence: Double
    }
    
    // MARK: - Initialization
    
    init(apiKey: String, deviceManager: SmartHomeManager) {
        self.client = DeepSeekClient(apiKey: apiKey)
        self.deviceManager = deviceManager
        
        loadAutomations()
        startPatternAnalysis()
    }
    
    private func loadAutomations() {
        // Load existing automations
        automations = [
            SmartAutomation(
                name: "Good Morning Routine",
                description: "Turns on lights and adjusts temperature when you wake up",
                trigger: SmartAutomation.Trigger(type: .time, value: "07:00"),
                conditions: [
                    SmartAutomation.Condition(type: .dayOfWeek, value: "weekday", comparison: .equals)
                ],
                actions: [
                    SmartAutomation.Action(deviceId: "light_001", command: "turn_on", parameters: ["brightness": "80"], delay: nil),
                    SmartAutomation.Action(deviceId: "thermostat_001", command: "set_temperature", parameters: ["value": "72"], delay: 300)
                ],
                isEnabled: true,
                createdBy: .user,
                executionCount: 45,
                lastExecuted: Date().addingTimeInterval(-86400)
            )
        ]
    }
    
    // MARK: - Pattern Analysis
    
    private func startPatternAnalysis() {
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task {
                    await self.analyzeUsagePatterns()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func analyzeUsagePatterns() async {
        isAnalyzing = true
        
        // Simulate pattern detection
        usagePatterns = [
            UsagePattern(
                pattern: "Lights turned on between 6-7 PM daily",
                frequency: 28,
                timeRange: DateInterval(start: Date().addingTimeInterval(-2592000), end: Date()),
                devices: ["light_001", "light_002"],
                confidence: 0.92
            ),
            UsagePattern(
                pattern: "Temperature lowered at bedtime",
                frequency: 20,
                timeRange: DateInterval(start: Date().addingTimeInterval(-2592000), end: Date()),
                devices: ["thermostat_001"],
                confidence: 0.85
            ),
            UsagePattern(
                pattern: "All devices off when leaving home",
                frequency: 15,
                timeRange: DateInterval(start: Date().addingTimeInterval(-1296000), end: Date()),
                devices: ["all"],
                confidence: 0.78
            )
        ]
        
        // Generate suggestions based on patterns
        await generateAutomationSuggestions()
        
        isAnalyzing = false
    }
    
    // MARK: - AI Suggestion Generation
    
    @MainActor
    private func generateAutomationSuggestions() async {
        do {
            let prompt = createSuggestionPrompt()
            
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: [
                    Message(role: .system, content: """
                    You are a smart home automation expert. Analyze usage patterns and suggest 
                    helpful automations that save energy, increase comfort, and improve convenience.
                    Focus on practical suggestions that users will actually use.
                    """),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.7
            )
            
            let response = try await client.chat.completions(request)
            
            if let content = response.choices.first?.message.content {
                parseSuggestions(from: content)
            }
        } catch {
            print("Failed to generate suggestions: \(error)")
        }
    }
    
    private func createSuggestionPrompt() -> String {
        """
        Based on these usage patterns:
        \(usagePatterns.map { "- \($0.pattern) (confidence: \($0.confidence))" }.joined(separator: "\n"))
        
        Current devices:
        \(deviceManager.devices.map { "- \($0.name) (\($0.type.rawValue)) in \($0.room)" }.joined(separator: "\n"))
        
        Suggest 3-5 automation rules that would be helpful. For each suggestion, provide:
        1. Name and description
        2. Trigger and conditions
        3. Actions to perform
        4. Reason why this would be helpful
        5. Estimated energy savings or comfort improvement
        """
    }
    
    private func parseSuggestions(from response: String) {
        // Parse AI response and create suggestions
        // This is simplified - in production, use structured output
        
        suggestions = [
            AutomationSuggestion(
                automation: SmartAutomation(
                    name: "Evening Arrival",
                    description: "Automatically prepare your home when you arrive in the evening",
                    trigger: SmartAutomation.Trigger(type: .location, value: "arriving_home"),
                    conditions: [
                        SmartAutomation.Condition(type: .timeRange, value: "17:00-22:00", comparison: .equals)
                    ],
                    actions: [
                        SmartAutomation.Action(deviceId: "light_001", command: "turn_on", parameters: ["brightness": "60"], delay: nil),
                        SmartAutomation.Action(deviceId: "thermostat_001", command: "set_temperature", parameters: ["value": "72"], delay: nil)
                    ],
                    isEnabled: false,
                    createdBy: .ai
                ),
                reason: "You frequently turn on lights and adjust temperature when arriving home in the evening",
                confidence: 0.88,
                potentialSavings: AutomationSuggestion.Savings(
                    energy: 15.5,
                    cost: 2.30,
                    comfort: 0.9
                )
            ),
            AutomationSuggestion(
                automation: SmartAutomation(
                    name: "Bedtime Energy Saver",
                    description: "Optimize energy usage during sleep hours",
                    trigger: SmartAutomation.Trigger(type: .time, value: "23:00"),
                    conditions: [],
                    actions: [
                        SmartAutomation.Action(deviceId: "light_001", command: "turn_off", parameters: [:], delay: nil),
                        SmartAutomation.Action(deviceId: "thermostat_001", command: "set_temperature", parameters: ["value": "68"], delay: 600),
                        SmartAutomation.Action(deviceId: "plug_001", command: "turn_off", parameters: [:], delay: nil)
                    ],
                    isEnabled: false,
                    createdBy: .ai
                ),
                reason: "Save energy by automatically adjusting devices for nighttime",
                confidence: 0.92,
                potentialSavings: AutomationSuggestion.Savings(
                    energy: 25.0,
                    cost: 3.75,
                    comfort: 0.85
                )
            )
        ]
    }
    
    // MARK: - Automation Management
    
    func enableAutomation(_ automation: SmartAutomation) {
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index].isEnabled = true
        } else {
            var newAutomation = automation
            newAutomation.isEnabled = true
            automations.append(newAutomation)
        }
    }
    
    func executeAutomation(_ automation: SmartAutomation) async {
        guard automation.isEnabled else { return }
        
        // Check conditions
        if !checkConditions(automation.conditions) {
            return
        }
        
        // Execute actions
        for action in automation.actions {
            if let delay = action.delay {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            await deviceManager.controlDevice(
                deviceId: action.deviceId,
                action: action.command,
                value: action.parameters.first?.value
            )
        }
        
        // Update execution stats
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index].executionCount += 1
            automations[index].lastExecuted = Date()
        }
    }
    
    private func checkConditions(_ conditions: [SmartAutomation.Condition]) -> Bool {
        // Simplified condition checking
        for condition in conditions {
            switch condition.type {
            case .timeRange:
                // Check if current time is in range
                // Implementation needed
                break
            case .dayOfWeek:
                if condition.value == "weekday" {
                    let weekday = Calendar.current.component(.weekday, from: Date())
                    if weekday == 1 || weekday == 7 { // Sunday or Saturday
                        return false
                    }
                }
            default:
                break
            }
        }
        return true
    }
}

// MARK: - UI Components

struct AutomationSuggestionsView: View {
    @StateObject private var engine: SmartAutomationEngine
    @State private var selectedSuggestion: SmartAutomationEngine.AutomationSuggestion?
    @State private var showingCreateAutomation = false
    
    init(apiKey: String, deviceManager: SmartHomeManager) {
        _engine = StateObject(wrappedValue: SmartAutomationEngine(
            apiKey: apiKey,
            deviceManager: deviceManager
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Usage patterns
                if !engine.usagePatterns.isEmpty {
                    UsagePatternsSection(patterns: engine.usagePatterns)
                }
                
                // AI Suggestions
                if !engine.suggestions.isEmpty {
                    SuggestionsSection(
                        suggestions: engine.suggestions,
                        onSelect: { selectedSuggestion = $0 }
                    )
                }
                
                // Active automations
                ActiveAutomationsSection(
                    automations: engine.automations.filter { $0.isEnabled }
                )
                
                // Create custom automation
                Button(action: { showingCreateAutomation = true }) {
                    Label("Create Custom Automation", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Smart Automations")
        .sheet(item: $selectedSuggestion) { suggestion in
            SuggestionDetailView(
                suggestion: suggestion,
                onAccept: {
                    engine.enableAutomation(suggestion.automation)
                }
            )
        }
        .sheet(isPresented: $showingCreateAutomation) {
            CreateAutomationView(engine: engine)
        }
    }
}

struct UsagePatternsSection: View {
    let patterns: [SmartAutomationEngine.UsagePattern]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Patterns")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(patterns) { pattern in
                        PatternCard(pattern: pattern)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct PatternCard: View {
    let pattern: SmartAutomationEngine.UsagePattern
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(pattern.frequency) times", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(pattern.pattern)
                .font(.subheadline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                ConfidenceMeter(confidence: pattern.confidence)
                
                Spacer()
                
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .frame(width: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ConfidenceMeter: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(Double(index) < confidence * 5 ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 4)
                    .cornerRadius(2)
            }
        }
    }
}

struct SuggestionsSection: View {
    let suggestions: [SmartAutomationEngine.AutomationSuggestion]
    let onSelect: (SmartAutomationEngine.AutomationSuggestion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Suggestions")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
            }
            .padding(.horizontal)
            
            ForEach(suggestions) { suggestion in
                SuggestionCard(suggestion: suggestion, onTap: {
                    onSelect(suggestion)
                })
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: SmartAutomationEngine.AutomationSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.automation.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(suggestion.automation.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                Text(suggestion.reason)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                if let savings = suggestion.potentialSavings {
                    SavingsIndicator(savings: savings)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

struct SavingsIndicator: View {
    let savings: SmartAutomationEngine.AutomationSuggestion.Savings
    
    var body: some View {
        HStack(spacing: 16) {
            Label("$\(String(format: "%.2f", savings.cost))/mo", systemImage: "dollarsign.circle")
                .font(.caption)
                .foregroundColor(.green)
            
            Label("\(Int(savings.energy)) kWh", systemImage: "bolt.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            
            Label("\(Int(savings.comfort * 100))% comfort", systemImage: "house.fill")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
}

struct ActiveAutomationsSection: View {
    let automations: [SmartAutomationEngine.SmartAutomation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Automations")
                .font(.headline)
                .padding(.horizontal)
            
            if automations.isEmpty {
                Text("No active automations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(automations) { automation in
                    ActiveAutomationRow(automation: automation)
                }
            }
        }
    }
}

struct ActiveAutomationRow: View {
    let automation: SmartAutomationEngine.SmartAutomation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(automation.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Label(automation.trigger.type.rawValue, systemImage: triggerIcon)
                        .font(.caption)
                    
                    if automation.executionCount > 0 {
                        Text("• \(automation.executionCount) runs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(automation.isEnabled))
                .labelsHidden()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var triggerIcon: String {
        switch automation.trigger.type {
        case .time: return "clock"
        case .deviceState: return "cpu"
        case .location: return "location"
        case .weather: return "cloud.sun"
        case .motion: return "figure.walk"
        case .voice: return "mic"
        }
    }
}

struct SuggestionDetailView: View {
    let suggestion: SmartAutomationEngine.AutomationSuggestion
    let onAccept: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.automation.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(suggestion.automation.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Reason
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Why this suggestion?", systemImage: "lightbulb")
                            .font(.headline)
                        
                        Text(suggestion.reason)
                            .font(.body)
                    }
                    .padding()
                    
                    // Trigger & Conditions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When to run")
                            .font(.headline)
                        
                        Label(
                            "\(suggestion.automation.trigger.type.rawValue): \(suggestion.automation.trigger.value)",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(.subheadline)
                        
                        if !suggestion.automation.conditions.isEmpty {
                            Text("Conditions:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(suggestion.automation.conditions, id: \.value) { condition in
                                Text("• \(condition.type.rawValue) \(condition.comparison.rawValue) \(condition.value)")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What it does")
                            .font(.headline)
                        
                        ForEach(Array(suggestion.automation.actions.enumerated()), id: \.offset) { index, action in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading) {
                                    Text("\(action.command) - Device \(action.deviceId)")
                                        .font(.subheadline)
                                    
                                    if let delay = action.delay {
                                        Text("After \(Int(delay))s delay")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Savings
                    if let savings = suggestion.potentialSavings {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Estimated Savings")
                                .font(.headline)
                            
                            HStack(spacing: 20) {
                                VStack {
                                    Text("$\(String(format: "%.2f", savings.cost))")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    Text("per month")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(Int(savings.energy))")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.yellow)
                                    Text("kWh saved")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(Int(savings.comfort * 100))%")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                    Text("comfort")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.1), Color.yellow.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    // Accept button
                    Button(action: {
                        onAccept()
                        dismiss()
                    }) {
                        Text("Enable This Automation")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Automation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct CreateAutomationView: View {
    let engine: SmartAutomationEngine
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedTrigger = SmartAutomationEngine.SmartAutomation.Trigger.TriggerType.time
    @State private var triggerValue = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Automation Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Trigger") {
                    Picker("Trigger Type", selection: $selectedTrigger) {
                        Text("Time").tag(SmartAutomationEngine.SmartAutomation.Trigger.TriggerType.time)
                        Text("Device State").tag(SmartAutomationEngine.SmartAutomation.Trigger.TriggerType.deviceState)
                        Text("Location").tag(SmartAutomationEngine.SmartAutomation.Trigger.TriggerType.location)
                        Text("Weather").tag(SmartAutomationEngine.SmartAutomation.Trigger.TriggerType.weather)
                    }
                    
                    TextField("Trigger Value", text: $triggerValue)
                }
                
                Section("Actions") {
                    Text("Configure actions...")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Create Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        // Create automation
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}