import SwiftUI
import DeepSeekKit

// Build decision support systems
struct DecisionSupportView: View {
    @StateObject private var decisionSystem = DecisionSupportSystem()
    @State private var decisionContext = ""
    @State private var decisionType: DecisionType = .strategic
    @State private var showingAnalysis = false
    
    enum DecisionType: String, CaseIterable {
        case strategic = "Strategic"
        case tactical = "Tactical"
        case operational = "Operational"
        case financial = "Financial"
        case technical = "Technical"
        
        var icon: String {
            switch self {
            case .strategic: return "star.circle"
            case .tactical: return "target"
            case .operational: return "gearshape.2"
            case .financial: return "dollarsign.circle"
            case .technical: return "cpu"
            }
        }
        
        var color: Color {
            switch self {
            case .strategic: return .purple
            case .tactical: return .blue
            case .operational: return .green
            case .financial: return .orange
            case .technical: return .red
            }
        }
        
        var criteria: [String] {
            switch self {
            case .strategic:
                return ["Long-term impact", "Market position", "Competitive advantage", "Resource allocation"]
            case .tactical:
                return ["Short-term goals", "Team efficiency", "Process improvement", "Quick wins"]
            case .operational:
                return ["Daily operations", "Workflow optimization", "Cost efficiency", "Quality control"]
            case .financial:
                return ["ROI analysis", "Budget impact", "Risk assessment", "Cash flow"]
            case .technical:
                return ["Technical feasibility", "Scalability", "Security", "Maintenance"]
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Decision context input
                DecisionContextSection(
                    context: $decisionContext,
                    type: $decisionType
                )
                
                // Decision criteria
                DecisionCriteriaView(
                    criteria: decisionType.criteria,
                    weights: decisionSystem.criteriaWeights
                )
                
                // Analyze button
                Button(action: analyzeDecision) {
                    if decisionSystem.isAnalyzing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Label("Analyze Decision", systemImage: "brain")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(decisionContext.isEmpty || decisionSystem.isAnalyzing)
                
                // Current analysis
                if let analysis = decisionSystem.currentAnalysis {
                    DecisionAnalysisView(analysis: analysis)
                }
                
                // Decision history
                if !decisionSystem.decisionHistory.isEmpty {
                    DecisionHistorySection(
                        history: decisionSystem.decisionHistory,
                        onSelect: { analysis in
                            decisionSystem.currentAnalysis = analysis
                            showingAnalysis = true
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Decision Support")
        .sheet(isPresented: $showingAnalysis) {
            if let analysis = decisionSystem.currentAnalysis {
                DetailedAnalysisView(analysis: analysis)
            }
        }
    }
    
    private func analyzeDecision() {
        Task {
            await decisionSystem.analyzeDecision(
                context: decisionContext,
                type: decisionType
            )
        }
    }
}

// MARK: - Decision Support System

class DecisionSupportSystem: ObservableObject {
    @Published var currentAnalysis: DecisionAnalysis?
    @Published var decisionHistory: [DecisionAnalysis] = []
    @Published var isAnalyzing = false
    @Published var criteriaWeights: [String: Double] = [:]
    
    private let client: DeepSeekClient
    
    init() {
        self.client = DeepSeekClient(apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "")
    }
    
    func analyzeDecision(context: String, type: DecisionSupportView.DecisionType) async {
        await MainActor.run { isAnalyzing = true }
        
        do {
            let messages: [Message] = [
                Message(role: .system, content: """
                    You are a decision support AI that helps analyze complex decisions using reasoning.
                    Provide structured analysis including:
                    1. Problem definition and context
                    2. Available options/alternatives
                    3. Evaluation criteria
                    4. Risk assessment
                    5. Recommendations with reasoning
                    
                    Focus on \(type.rawValue.lowercased()) decisions.
                    """),
                Message(role: .user, content: context)
            ]
            
            let params = ChatCompletionParameters(
                model: "deepseek-reasoner",
                messages: messages,
                temperature: 0.1,
                maxTokens: 4000
            )
            
            let response = try await client.chatCompletion(params: params)
            
            if let content = response.choices.first?.message.content {
                let analysis = DecisionAnalysis(
                    id: UUID().uuidString,
                    context: context,
                    type: type,
                    options: extractOptions(from: content),
                    risks: extractRisks(from: content),
                    recommendation: extractRecommendation(from: content),
                    reasoning: extractReasoning(from: content),
                    confidence: calculateConfidence(from: content),
                    timestamp: Date()
                )
                
                await MainActor.run {
                    self.currentAnalysis = analysis
                    self.decisionHistory.append(analysis)
                    self.isAnalyzing = false
                }
            }
        } catch {
            print("Error analyzing decision: \(error)")
            await MainActor.run { isAnalyzing = false }
        }
    }
    
    private func extractOptions(from content: String) -> [DecisionOption] {
        // Extract decision options from the response
        var options: [DecisionOption] = []
        
        let optionPattern = #"Option \d+: (.+?)(?=Option \d+:|Risks:|$)"#
        if let regex = try? NSRegularExpression(pattern: optionPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: content) {
                    let optionText = String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let option = DecisionOption(
                        title: optionText.components(separatedBy: "\n").first ?? optionText,
                        description: optionText,
                        pros: extractPros(from: optionText),
                        cons: extractCons(from: optionText),
                        score: calculateScore(from: optionText)
                    )
                    options.append(option)
                }
            }
        }
        
        return options
    }
    
    private func extractRisks(from content: String) -> [RiskAssessment] {
        // Extract risk assessments
        var risks: [RiskAssessment] = []
        
        if let risksRange = content.range(of: "Risks:") {
            let risksSection = String(content[risksRange.upperBound...])
            let riskLines = risksSection.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for line in riskLines {
                if line.contains("Risk") || line.contains("risk") {
                    let severity = determineSeverity(from: line)
                    let risk = RiskAssessment(
                        description: line,
                        severity: severity,
                        likelihood: determineLikelihood(from: line),
                        mitigation: extractMitigation(from: line)
                    )
                    risks.append(risk)
                }
            }
        }
        
        return risks
    }
    
    private func extractRecommendation(from content: String) -> String {
        if let recRange = content.range(of: "Recommendation:") {
            let recSection = String(content[recRange.upperBound...])
            return recSection.components(separatedBy: "\n\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return ""
    }
    
    private func extractReasoning(from content: String) -> String {
        if content.contains("<Thought>") && content.contains("</Thought>") {
            if let start = content.range(of: "<Thought>"),
               let end = content.range(of: "</Thought>") {
                return String(content[start.upperBound..<end.lowerBound])
            }
        }
        return ""
    }
    
    private func calculateConfidence(from content: String) -> Double {
        // Calculate confidence based on various factors
        var confidence = 0.5
        
        if content.contains("strongly recommend") { confidence += 0.2 }
        if content.contains("clear evidence") { confidence += 0.1 }
        if content.contains("high confidence") { confidence += 0.1 }
        if content.contains("uncertain") { confidence -= 0.2 }
        if content.contains("limited information") { confidence -= 0.1 }
        
        return max(0.0, min(1.0, confidence))
    }
    
    private func extractPros(from text: String) -> [String] {
        var pros: [String] = []
        let lines = text.components(separatedBy: "\n")
        
        for line in lines {
            if line.contains("Pros:") || line.contains("Advantages:") || line.contains("+") {
                pros.append(line.replacingOccurrences(of: "Pros:", with: "")
                    .replacingOccurrences(of: "Advantages:", with: "")
                    .replacingOccurrences(of: "+", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        return pros.filter { !$0.isEmpty }
    }
    
    private func extractCons(from text: String) -> [String] {
        var cons: [String] = []
        let lines = text.components(separatedBy: "\n")
        
        for line in lines {
            if line.contains("Cons:") || line.contains("Disadvantages:") || line.contains("-") {
                cons.append(line.replacingOccurrences(of: "Cons:", with: "")
                    .replacingOccurrences(of: "Disadvantages:", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        return cons.filter { !$0.isEmpty }
    }
    
    private func calculateScore(from text: String) -> Double {
        // Simple scoring based on pros vs cons
        let pros = extractPros(from: text).count
        let cons = extractCons(from: text).count
        
        if pros + cons == 0 { return 0.5 }
        return Double(pros) / Double(pros + cons)
    }
    
    private func determineSeverity(from text: String) -> RiskSeverity {
        let lowercased = text.lowercased()
        if lowercased.contains("critical") || lowercased.contains("severe") {
            return .critical
        } else if lowercased.contains("high") {
            return .high
        } else if lowercased.contains("medium") || lowercased.contains("moderate") {
            return .medium
        } else {
            return .low
        }
    }
    
    private func determineLikelihood(from text: String) -> Double {
        let lowercased = text.lowercased()
        if lowercased.contains("very likely") || lowercased.contains("probable") {
            return 0.8
        } else if lowercased.contains("likely") {
            return 0.6
        } else if lowercased.contains("possible") {
            return 0.4
        } else if lowercased.contains("unlikely") {
            return 0.2
        } else {
            return 0.5
        }
    }
    
    private func extractMitigation(from text: String) -> String {
        if let mitRange = text.range(of: "Mitigation:") {
            return String(text[mitRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}

// MARK: - Data Models

struct DecisionAnalysis: Identifiable {
    let id: String
    let context: String
    let type: DecisionSupportView.DecisionType
    let options: [DecisionOption]
    let risks: [RiskAssessment]
    let recommendation: String
    let reasoning: String
    let confidence: Double
    let timestamp: Date
}

struct DecisionOption: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let pros: [String]
    let cons: [String]
    let score: Double
}

struct RiskAssessment: Identifiable {
    let id = UUID()
    let description: String
    let severity: RiskSeverity
    let likelihood: Double
    let mitigation: String
}

enum RiskSeverity: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Supporting Views

struct DecisionContextSection: View {
    @Binding var context: String
    @Binding var type: DecisionSupportView.DecisionType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Decision Context")
                .font(.headline)
            
            TextEditor(text: $context)
                .frame(height: 120)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            HStack {
                Text("Decision Type:")
                    .font(.subheadline)
                
                Picker("Type", selection: $type) {
                    ForEach(DecisionSupportView.DecisionType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
}

struct DecisionCriteriaView: View {
    let criteria: [String]
    let weights: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Decision Criteria")
                .font(.headline)
            
            ForEach(criteria, id: \.self) { criterion in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(criterion)
                        .font(.subheadline)
                    Spacer()
                    if let weight = weights[criterion] {
                        Text("\(Int(weight * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct DecisionAnalysisView: View {
    let analysis: DecisionAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Recommendation
            VStack(alignment: .leading, spacing: 8) {
                Label("Recommendation", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text(analysis.recommendation)
                    .font(.body)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                HStack {
                    Text("Confidence:")
                        .font(.caption)
                    ProgressView(value: analysis.confidence)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("\(Int(analysis.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Options
            if !analysis.options.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Options Analyzed")
                        .font(.headline)
                    
                    ForEach(analysis.options) { option in
                        OptionCard(option: option)
                    }
                }
            }
            
            // Risks
            if !analysis.risks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Risk Assessment")
                        .font(.headline)
                    
                    ForEach(analysis.risks) { risk in
                        RiskCard(risk: risk)
                    }
                }
            }
        }
    }
}

struct OptionCard: View {
    let option: DecisionOption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(option.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Pros")
                        .font(.caption)
                        .foregroundColor(.green)
                    ForEach(option.pros, id: \.self) { pro in
                        Text("• \(pro)")
                            .font(.caption2)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Cons")
                        .font(.caption)
                        .foregroundColor(.red)
                    ForEach(option.cons, id: \.self) { con in
                        Text("• \(con)")
                            .font(.caption2)
                    }
                }
            }
            
            ProgressView(value: option.score)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct RiskCard: View {
    let risk: RiskAssessment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(risk.severity.rawValue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(risk.severity.color)
                
                Spacer()
                
                Text("Likelihood: \(Int(risk.likelihood * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(risk.description)
                .font(.caption)
            
            if !risk.mitigation.isEmpty {
                Text("Mitigation: \(risk.mitigation)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(risk.severity.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DecisionHistorySection: View {
    let history: [DecisionAnalysis]
    let onSelect: (DecisionAnalysis) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Decision History")
                .font(.headline)
            
            ForEach(history.reversed()) { analysis in
                Button(action: { onSelect(analysis) }) {
                    HStack {
                        Image(systemName: analysis.type.icon)
                            .foregroundColor(analysis.type.color)
                        
                        VStack(alignment: .leading) {
                            Text(analysis.context)
                                .lineLimit(1)
                                .font(.subheadline)
                            Text(analysis.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(analysis.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct DetailedAnalysisView: View {
    let analysis: DecisionAnalysis
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Context
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Context", systemImage: "doc.text")
                            .font(.headline)
                        Text(analysis.context)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                    }
                    
                    // Full analysis
                    DecisionAnalysisView(analysis: analysis)
                    
                    // Reasoning
                    if !analysis.reasoning.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Reasoning Process", systemImage: "brain")
                                .font(.headline)
                            
                            ScrollView {
                                Text(analysis.reasoning)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                            }
                            .frame(maxHeight: 300)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Decision Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - App

struct DecisionSupportApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                DecisionSupportView()
            }
        }
    }
}