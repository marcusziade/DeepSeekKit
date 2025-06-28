import SwiftUI
import DeepSeekKit

class ConversationManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var conversationId = UUID()
    
    private let client: DeepSeekClient
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
        setupNewConversation()
    }
    
    func setupNewConversation() {
        messages = [
            Message(role: .system, content: """
                You are a helpful AI assistant. 
                Remember our conversation context and refer back to previous messages when relevant.
                """)
        ]
    }
    
    func sendMessage(_ content: String) async throws -> String {
        // Add user message to history
        addUserMessage(content)
        
        // Send entire conversation history for context
        let request = ChatCompletionRequest(
            model: .deepSeekChat,
            messages: messages,
            temperature: 0.7
        )
        
        let response = try await client.chat.completions(request)
        let assistantReply = response.choices.first?.message.content ?? ""
        
        // Add assistant response to maintain continuity
        addAssistantMessage(assistantReply)
        
        return assistantReply
    }
    
    func addUserMessage(_ content: String) {
        messages.append(Message(role: .user, content: content))
    }
    
    func addAssistantMessage(_ content: String) {
        messages.append(Message(role: .assistant, content: content))
    }
    
    // Example: Reference previous context
    func demonstrateContinuity() async {
        do {
            // First message
            _ = try await sendMessage("My name is Alice and I love hiking.")
            
            // Second message references first
            _ = try await sendMessage("What outdoor activities would you recommend for someone like me?")
            // AI will remember Alice loves hiking
            
            // Third message builds on context
            _ = try await sendMessage("Are there any good trails near San Francisco?")
            // AI maintains context about hiking interest and can provide specific recommendations
        } catch {
            print("Error: \(error)")
        }
    }
}