import SwiftUI
import DeepSeekKit

// Extended Message type with Codable support
struct StorableMessage: Codable, Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let metadata: MessageMetadata?
    
    init(id: UUID = UUID(),
         role: MessageRole,
         content: String,
         timestamp: Date = Date(),
         metadata: MessageMetadata? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    init(from message: Message) {
        self.id = UUID()
        self.role = message.role
        self.content = message.content
        self.timestamp = Date()
        self.metadata = nil
    }
    
    var message: Message {
        Message(role: role, content: content)
    }
}

// Additional metadata for messages
struct MessageMetadata: Codable {
    let model: String?
    let tokensUsed: Int?
    let responseTime: TimeInterval?
    let error: String?
}

// Conversation container
struct Conversation: Codable, Identifiable {
    let id: UUID
    let title: String
    let messages: [StorableMessage]
    let createdAt: Date
    let updatedAt: Date
    let tags: [String]
    
    init(id: UUID = UUID(),
         title: String,
         messages: [StorableMessage] = [],
         tags: [String] = []) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }
    
    func updated(with messages: [StorableMessage]) -> Conversation {
        Conversation(
            id: id,
            title: title,
            messages: messages,
            tags: tags
        )
    }
}

// Storage manager
class ConversationStorage: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    
    private let documentsDirectory: URL
    private let conversationsFile = "conversations.json"
    
    init() {
        // Get documents directory
        self.documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        loadConversations()
    }
    
    // MARK: - Save/Load
    
    func saveConversations() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(conversations)
            let url = documentsDirectory.appendingPathComponent(conversationsFile)
            try data.write(to: url)
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }
    
    func loadConversations() {
        let url = documentsDirectory.appendingPathComponent(conversationsFile)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            conversations = try decoder.decode([Conversation].self, from: data)
        } catch {
            print("Failed to load conversations: \(error)")
        }
    }
    
    // MARK: - Conversation Management
    
    func createConversation(title: String) -> Conversation {
        let conversation = Conversation(title: title)
        conversations.append(conversation)
        currentConversation = conversation
        saveConversations()
        return conversation
    }
    
    func updateCurrentConversation(with messages: [StorableMessage]) {
        guard let current = currentConversation else { return }
        
        let updated = current.updated(with: messages)
        
        if let index = conversations.firstIndex(where: { $0.id == current.id }) {
            conversations[index] = updated
            currentConversation = updated
            saveConversations()
        }
    }
    
    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }
        saveConversations()
    }
    
    // MARK: - Export/Import
    
    func exportConversation(_ conversation: Conversation) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(conversation)
        } catch {
            print("Failed to export conversation: \(error)")
            return nil
        }
    }
    
    func importConversation(from data: Data) -> Conversation? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let conversation = try decoder.decode(Conversation.self, from: data)
            conversations.append(conversation)
            saveConversations()
            return conversation
        } catch {
            print("Failed to import conversation: \(error)")
            return nil
        }
    }
    
    // MARK: - Search
    
    func searchConversations(query: String) -> [Conversation] {
        guard !query.isEmpty else { return conversations }
        
        return conversations.filter { conversation in
            // Search in title
            if conversation.title.localizedCaseInsensitiveContains(query) {
                return true
            }
            
            // Search in messages
            return conversation.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    // MARK: - Statistics
    
    var totalMessageCount: Int {
        conversations.reduce(0) { $0 + $1.messages.count }
    }
    
    var averageConversationLength: Double {
        guard !conversations.isEmpty else { return 0 }
        return Double(totalMessageCount) / Double(conversations.count)
    }
    
    func mostUsedTags() -> [(String, Int)] {
        var tagCounts: [String: Int] = [:]
        
        for conversation in conversations {
            for tag in conversation.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        
        return tagCounts.sorted { $0.value > $1.value }
    }
}