import SwiftUI
import CoreData
import DeepSeekKit

// Core Data Model (defined in .xcdatamodeld file)
// ConversationEntity: id, title, createdAt, updatedAt
// MessageEntity: id, role, content, timestamp, conversation (relationship)

// Core Data Stack
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ConversationModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// Core Data Manager
class CoreDataConversationManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    @Published var conversations: [ConversationEntity] = []
    @Published var currentConversation: ConversationEntity?
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        fetchConversations()
    }
    
    // MARK: - Fetch
    
    func fetchConversations() {
        let request: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationEntity.updatedAt, ascending: false)]
        
        do {
            conversations = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch conversations: \(error)")
        }
    }
    
    // MARK: - Create
    
    func createConversation(title: String) -> ConversationEntity {
        let conversation = ConversationEntity(context: viewContext)
        conversation.id = UUID()
        conversation.title = title
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        
        currentConversation = conversation
        save()
        fetchConversations()
        
        return conversation
    }
    
    func addMessage(to conversation: ConversationEntity,
                   role: MessageRole,
                   content: String) -> MessageEntity {
        let message = MessageEntity(context: viewContext)
        message.id = UUID()
        message.role = role.rawValue
        message.content = content
        message.timestamp = Date()
        message.conversation = conversation
        
        conversation.updatedAt = Date()
        
        save()
        return message
    }
    
    // MARK: - Update
    
    func updateConversationTitle(_ conversation: ConversationEntity, title: String) {
        conversation.title = title
        conversation.updatedAt = Date()
        save()
    }
    
    // MARK: - Delete
    
    func deleteConversation(_ conversation: ConversationEntity) {
        viewContext.delete(conversation)
        
        if currentConversation == conversation {
            currentConversation = nil
        }
        
        save()
        fetchConversations()
    }
    
    func deleteMessage(_ message: MessageEntity) {
        if let conversation = message.conversation {
            conversation.updatedAt = Date()
        }
        
        viewContext.delete(message)
        save()
    }
    
    // MARK: - Save
    
    private func save() {
        guard viewContext.hasChanges else { return }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    // MARK: - Search
    
    func searchConversations(query: String) -> [ConversationEntity] {
        guard !query.isEmpty else { return conversations }
        
        let request: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR ANY messages.content CONTAINS[cd] %@",
            query, query
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationEntity.updatedAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Search failed: \(error)")
            return []
        }
    }
    
    // MARK: - Statistics
    
    func conversationStatistics() -> ConversationStats {
        let conversationCount = conversations.count
        let messageCount = conversations.reduce(0) { total, conversation in
            total + (conversation.messages?.count ?? 0)
        }
        
        let avgLength = conversationCount > 0 ? Double(messageCount) / Double(conversationCount) : 0
        
        return ConversationStats(
            totalConversations: conversationCount,
            totalMessages: messageCount,
            averageLength: avgLength
        )
    }
}

struct ConversationStats {
    let totalConversations: Int
    let totalMessages: Int
    let averageLength: Double
}

// MARK: - Views

struct CoreDataConversationListView: View {
    @StateObject private var manager = CoreDataConversationManager()
    @State private var showingNewConversation = false
    @State private var searchText = ""
    
    var filteredConversations: [ConversationEntity] {
        if searchText.isEmpty {
            return manager.conversations
        } else {
            return manager.searchConversations(query: searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredConversations) { conversation in
                    NavigationLink(destination: ConversationDetailView(conversation: conversation)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title ?? "Untitled")
                                .font(.headline)
                            
                            if let lastMessage = conversation.sortedMessages.last {
                                Text(lastMessage.content ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Text(conversation.updatedAt ?? Date(), style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteConversations)
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .navigationTitle("Conversations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewConversation = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewConversation) {
                NewConversationView(manager: manager)
            }
        }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = filteredConversations[index]
            manager.deleteConversation(conversation)
        }
    }
}

struct ConversationDetailView: View {
    let conversation: ConversationEntity
    @EnvironmentObject var manager: CoreDataConversationManager
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(conversation.sortedMessages) { message in
                    MessageRow(message: message)
                }
            }
            .padding()
        }
        .navigationTitle(conversation.title ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MessageRow: View {
    let message: MessageEntity
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading) {
                Text(message.role ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(message.content ?? "")
                    .padding(8)
                    .background(message.role == "user" ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .cornerRadius(12)
            }
            
            if message.role != "user" {
                Spacer()
            }
        }
    }
}

struct NewConversationView: View {
    @ObservedObject var manager: CoreDataConversationManager
    @State private var title = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Conversation Title", text: $title)
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        _ = manager.createConversation(title: title.isEmpty ? "New Conversation" : title)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Core Data Extensions

extension ConversationEntity {
    var sortedMessages: [MessageEntity] {
        let set = messages as? Set<MessageEntity> ?? []
        return set.sorted {
            ($0.timestamp ?? Date()) < ($1.timestamp ?? Date())
        }
    }
}

// Make entities identifiable
extension ConversationEntity: Identifiable {}
extension MessageEntity: Identifiable {}