import SwiftUI
import DeepSeekKit

struct UsageTracking: View {
    @StateObject private var client = DeepSeekClient()
    @State private var messages: [TrackedMessage] = []
    @State private var currentMessage = ""
    @State private var isLoading = false
    @State private var selectedModel: DeepSeekModel = .chat
    
    struct TrackedMessage {
        let id = UUID()
        let content: String
        let role: String
        let model: DeepSeekModel
        let usage: TokenUsage?
        let timestamp: Date
    }
    
    struct TokenUsage {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        let estimatedCost: Double
        
        // Rough cost estimation (adjust based on actual pricing)
        init(from usage: Usage, model: DeepSeekModel) {
            self.promptTokens = usage.promptTokens
            self.completionTokens = usage.completionTokens
            self.totalTokens = usage.totalTokens
            
            // Example pricing per 1M tokens (adjust to actual rates)
            let promptRate = model == .chat ? 0.14 : 0.55  // $ per 1M tokens
            let completionRate = model == .chat ? 0.28 : 2.19
            
            let promptCost = Double(promptTokens) / 1_000_000 * promptRate
            let completionCost = Double(completionTokens) / 1_000_000 * completionRate
            self.estimatedCost = promptCost + completionCost
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Usage Summary
                UsageSummaryView(messages: messages)
                
                // Model Selector
                Picker("Model", selection: $selectedModel) {
                    Text("Chat").tag(DeepSeekModel.chat)
                    Text("Reasoner").tag(DeepSeekModel.reasoner)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Message List
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(messages, id: \.id) { message in
                            MessageUsageView(message: message)
                        }
                    }
                    .padding()
                }
                
                // Input Area
                HStack {
                    TextField("Type a message...", text: $currentMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(currentMessage.isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("Token Usage Tracking")
        }
    }
    
    private func sendMessage() {
        let userMessage = currentMessage
        currentMessage = ""
        
        // Add user message
        messages.append(TrackedMessage(
            content: userMessage,
            role: "user",
            model: selectedModel,
            usage: nil,
            timestamp: Date()
        ))
        
        Task {
            isLoading = true
            
            do {
                // Create conversation history
                let chatMessages = messages.compactMap { msg in
                    msg.role == "user" ? Message.user(msg.content) :
                    msg.role == "assistant" ? Message.assistant(msg.content) : nil
                }
                
                // Add current message
                let allMessages = chatMessages + [.user(userMessage)]
                
                // Send request
                let response = try await client.chat(
                    messages: allMessages,
                    model: selectedModel
                )
                
                // Extract response and usage
                if let choice = response.choices.first,
                   let content = choice.message.content {
                    
                    let usage = response.usage.map { TokenUsage(from: $0, model: selectedModel) }
                    
                    messages.append(TrackedMessage(
                        content: content,
                        role: "assistant",
                        model: selectedModel,
                        usage: usage,
                        timestamp: Date()
                    ))
                }
            } catch {
                messages.append(TrackedMessage(
                    content: "Error: \(error.localizedDescription)",
                    role: "system",
                    model: selectedModel,
                    usage: nil,
                    timestamp: Date()
                ))
            }
            
            isLoading = false
        }
    }
}

struct UsageSummaryView: View {
    let messages: [UsageTracking.TrackedMessage]
    
    private var totalUsage: (prompt: Int, completion: Int, total: Int, cost: Double) {
        messages.reduce((0, 0, 0, 0.0)) { result, message in
            guard let usage = message.usage else { return result }
            return (
                result.0 + usage.promptTokens,
                result.1 + usage.completionTokens,
                result.2 + usage.totalTokens,
                result.3 + usage.estimatedCost
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Session Usage Summary")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Prompt Tokens
                VStack {
                    Image(systemName: "arrow.up.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("\(totalUsage.prompt)")
                        .font(.headline)
                    Text("Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Completion Tokens
                VStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("\(totalUsage.completion)")
                        .font(.headline)
                    Text("Completion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Total Tokens
                VStack {
                    Image(systemName: "sum")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("\(totalUsage.total)")
                        .font(.headline)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Estimated Cost
                VStack {
                    Image(systemName: "dollarsign.circle")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text(String(format: "$%.4f", totalUsage.cost))
                        .font(.headline)
                    Text("Est. Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
    }
}

struct MessageUsageView: View {
    let message: UsageTracking.TrackedMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message Header
            HStack {
                Image(systemName: iconForRole)
                    .foregroundColor(colorForRole)
                
                Text(message.role.capitalized)
                    .font(.caption)
                    .bold()
                
                Spacer()
                
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Message Content
            Text(message.content)
                .padding(10)
                .background(backgroundForRole)
                .cornerRadius(8)
            
            // Usage Info
            if let usage = message.usage {
                HStack(spacing: 15) {
                    Label("\(usage.promptTokens)", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Label("\(usage.completionTokens)", systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Label("\(usage.totalTokens)", systemImage: "sum")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text(String(format: "$%.4f", usage.estimatedCost))
                        .font(.caption)
                        .foregroundColor(.purple)
                        .bold()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)
            }
        }
    }
    
    private var iconForRole: String {
        switch message.role {
        case "user": return "person.circle"
        case "assistant": return "cpu"
        case "system": return "gear"
        default: return "questionmark.circle"
        }
    }
    
    private var colorForRole: Color {
        switch message.role {
        case "user": return .blue
        case "assistant": return .green
        case "system": return .orange
        default: return .gray
        }
    }
    
    private var backgroundForRole: Color {
        switch message.role {
        case "user": return Color.blue.opacity(0.1)
        case "assistant": return Color.green.opacity(0.1)
        case "system": return Color.orange.opacity(0.1)
        default: return Color.gray.opacity(0.1)
        }
    }
}