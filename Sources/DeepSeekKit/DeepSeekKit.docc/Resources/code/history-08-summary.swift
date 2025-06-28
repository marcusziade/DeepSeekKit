import SwiftUI
import DeepSeekKit

class ConversationSummarizer: ObservableObject {
    @Published var messages: [Message] = []
    @Published var summaries: [ConversationSummary] = []
    @Published var isSummarizing = false
    
    private let client: DeepSeekClient
    private let summaryThreshold = 10 // Summarize after N messages
    private let maxMessagesBeforeSummary = 30
    
    struct ConversationSummary {
        let id = UUID()
        let summary: String
        let messageCount: Int
        let timestamp: Date
        let topics: [String]
    }
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
        setupSystemMessage()
    }
    
    private func setupSystemMessage() {
        messages.append(Message(
            role: .system,
            content: """
            You are a helpful AI assistant. When asked to summarize, 
            create concise summaries that capture key points and context.
            """
        ))
    }
    
    func addUserMessage(_ content: String) {
        messages.append(Message(role: .user, content: content))
        checkForSummarization()
    }
    
    func addAssistantMessage(_ content: String) {
        messages.append(Message(role: .assistant, content: content))
    }
    
    private func checkForSummarization() {
        let nonSummaryMessages = messages.filter { message in
            !message.content.hasPrefix("[Summary of previous")
        }
        
        if nonSummaryMessages.count >= maxMessagesBeforeSummary {
            Task {
                await summarizeOldMessages()
            }
        }
    }
    
    @MainActor
    private func summarizeOldMessages() async {
        isSummarizing = true
        
        do {
            // Get messages to summarize (excluding system and recent)
            let messagesToSummarize = Array(messages.dropFirst().prefix(summaryThreshold))
            
            // Create summary request
            let summaryPrompt = createSummaryPrompt(for: messagesToSummarize)
            let summaryRequest = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: [
                    Message(role: .system, content: "You are a conversation summarizer. Create concise, informative summaries."),
                    Message(role: .user, content: summaryPrompt)
                ],
                temperature: 0.3 // Lower temperature for consistent summaries
            )
            
            let response = try await client.chat.completions(summaryRequest)
            if let summaryContent = response.choices.first?.message.content {
                // Parse summary and topics
                let (summary, topics) = parseSummaryResponse(summaryContent)
                
                // Store summary
                let conversationSummary = ConversationSummary(
                    summary: summary,
                    messageCount: messagesToSummarize.count,
                    timestamp: Date(),
                    topics: topics
                )
                summaries.append(conversationSummary)
                
                // Replace old messages with summary
                replaceMessagesWithSummary(
                    messagesToSummarize: messagesToSummarize,
                    summary: conversationSummary
                )
            }
        } catch {
            print("Summarization error: \(error)")
        }
        
        isSummarizing = false
    }
    
    private func createSummaryPrompt(for messages: [Message]) -> String {
        let conversation = messages.map { message in
            "\(message.role.rawValue): \(message.content)"
        }.joined(separator: "\n")
        
        return """
        Summarize the following conversation segment. Include:
        1. Main topics discussed
        2. Key decisions or conclusions
        3. Important information to remember
        4. Any unresolved questions
        
        Format your response as:
        SUMMARY: [Your summary here]
        TOPICS: [Comma-separated list of main topics]
        
        Conversation:
        \(conversation)
        """
    }
    
    private func parseSummaryResponse(_ response: String) -> (summary: String, topics: [String]) {
        var summary = ""
        var topics: [String] = []
        
        let lines = response.split(separator: "\n")
        for line in lines {
            if line.hasPrefix("SUMMARY:") {
                summary = String(line.dropFirst("SUMMARY:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("TOPICS:") {
                let topicsString = String(line.dropFirst("TOPICS:".count)).trimmingCharacters(in: .whitespaces)
                topics = topicsString.split(separator: ",").map { 
                    $0.trimmingCharacters(in: .whitespaces) 
                }
            }
        }
        
        return (summary, topics)
    }
    
    private func replaceMessagesWithSummary(
        messagesToSummarize: [Message],
        summary: ConversationSummary
    ) {
        // Find range to replace
        guard let firstIndex = messages.firstIndex(where: { msg in
            messagesToSummarize.contains(where: { $0.content == msg.content })
        }) else { return }
        
        let lastIndex = firstIndex + messagesToSummarize.count - 1
        
        // Create summary message
        let summaryMessage = Message(
            role: .assistant,
            content: """
            [Summary of previous \(summary.messageCount) messages]
            \(summary.summary)
            Topics covered: \(summary.topics.joined(separator: ", "))
            """
        )
        
        // Replace messages with summary
        messages.removeSubrange(firstIndex...lastIndex)
        messages.insert(summaryMessage, at: firstIndex)
    }
    
    func getFullContext() -> String {
        var context = ""
        
        // Add summaries first
        for summary in summaries {
            context += "[Previous conversation summary]\n"
            context += summary.summary + "\n\n"
        }
        
        // Add current messages
        for message in messages {
            context += "\(message.role.rawValue): \(message.content)\n"
        }
        
        return context
    }
}

// View to display summaries
struct SummaryView: View {
    @ObservedObject var summarizer: ConversationSummarizer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if summarizer.isSummarizing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Summarizing conversation...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            ForEach(summarizer.summaries) { summary in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text("Summary")
                            .font(.headline)
                        Spacer()
                        Text(summary.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(summary.summary)
                        .font(.body)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(summary.topics, id: \.self) { topic in
                                Text(topic)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}