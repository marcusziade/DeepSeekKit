import SwiftUI
import DeepSeekKit

// Conversation browser with search and filtering
struct ConversationBrowserView: View {
    @StateObject private var storage = ConversationStorage()
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var showingFilters = false
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case titleAscending = "Title A-Z"
        case titleDescending = "Title Z-A"
        case lengthDescending = "Longest First"
        
        var systemImage: String {
            switch self {
            case .dateDescending, .dateAscending:
                return "calendar"
            case .titleAscending, .titleDescending:
                return "textformat"
            case .lengthDescending:
                return "arrow.up.arrow.down"
            }
        }
    }
    
    var filteredConversations: [Conversation] {
        var conversations = storage.conversations
        
        // Apply search filter
        if !searchText.isEmpty {
            conversations = storage.searchConversations(query: searchText)
        }
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            conversations = conversations.filter { conversation in
                !selectedTags.isDisjoint(with: Set(conversation.tags))
            }
        }
        
        // Apply sorting
        switch sortOrder {
        case .dateDescending:
            conversations.sort { $0.updatedAt > $1.updatedAt }
        case .dateAscending:
            conversations.sort { $0.updatedAt < $1.updatedAt }
        case .titleAscending:
            conversations.sort { $0.title < $1.title }
        case .titleDescending:
            conversations.sort { $0.title > $1.title }
        case .lengthDescending:
            conversations.sort { $0.messages.count > $1.messages.count }
        }
        
        return conversations
    }
    
    var allTags: [String] {
        Array(Set(storage.conversations.flatMap { $0.tags })).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText)
                
                // Filter chips
                if !selectedTags.isEmpty || showingFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(allTags, id: \.self) { tag in
                                FilterChip(
                                    title: tag,
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    toggleTag(tag)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
                
                // Conversation list
                if filteredConversations.isEmpty {
                    EmptyStateView(searchText: searchText)
                } else {
                    List {
                        ForEach(filteredConversations) { conversation in
                            NavigationLink(
                                destination: ConversationDetailView(
                                    conversation: conversation,
                                    storage: storage
                                )
                            ) {
                                ConversationRow(conversation: conversation)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Conversations")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Label(order.rawValue, systemImage: order.systemImage)
                                    .tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showingFilters.toggle() }) {
                            Image(systemName: "line.horizontal.3.decrease.circle")
                                .foregroundColor(showingFilters ? .accentColor : .primary)
                        }
                        
                        Button(action: createNewConversation) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            storage.deleteConversation(filteredConversations[index])
        }
    }
    
    private func createNewConversation() {
        _ = storage.createConversation(title: "New Conversation")
    }
}

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search conversations...", text: $text)
                    .onTapGesture {
                        isEditing = true
                    }
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isEditing {
                Button("Cancel") {
                    text = ""
                    isEditing = false
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .transition(.move(edge: .trailing))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .animation(.default, value: isEditing)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let lastMessage = conversation.messages.last {
                HStack {
                    Image(systemName: iconForRole(lastMessage.role))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            HStack {
                Label("\(conversation.messages.count)", systemImage: "message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !conversation.tags.isEmpty {
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(conversation.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        if conversation.tags.count > 3 {
                            Text("+\(conversation.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForRole(_ role: MessageRole) -> String {
        switch role {
        case .system: return "gear"
        case .user: return "person.fill"
        case .assistant: return "cpu"
        case .function: return "function"
        }
    }
}

struct EmptyStateView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "No Conversations Yet" : "No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty ? 
                 "Start a new conversation to get started" : 
                 "Try adjusting your search or filters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Detail View

struct ConversationDetailView: View {
    let conversation: Conversation
    let storage: ConversationStorage
    
    @State private var showingExport = false
    @State private var showingInfo = false
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(conversation.messages) { message in
                    MessageBubbleView(message: message)
                }
            }
            .padding()
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingInfo = true }) {
                        Label("Info", systemImage: "info.circle")
                    }
                    
                    Button(action: { showingExport = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: deleteConversation) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportConversationView(conversation: conversation)
        }
        .sheet(isPresented: $showingInfo) {
            ConversationInfoView(conversation: conversation)
        }
    }
    
    private func deleteConversation() {
        storage.deleteConversation(conversation)
    }
}

struct MessageBubbleView: View {
    let message: StorableMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                HStack {
                    Text(message.role.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
            }
            
            if message.role != .user {
                Spacer()
            }
        }
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .system: return Color.orange.opacity(0.2)
        case .user: return Color.blue
        case .assistant: return Color(.systemGray5)
        case .function: return Color.green.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        message.role == .user ? .white : .primary
    }
}

struct ConversationInfoView: View {
    let conversation: Conversation
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Details") {
                    LabeledContent("Title", value: conversation.title)
                    LabeledContent("Created", value: conversation.createdAt, format: .dateTime)
                    LabeledContent("Updated", value: conversation.updatedAt, format: .dateTime)
                    LabeledContent("Messages", value: "\(conversation.messages.count)")
                }
                
                if !conversation.tags.isEmpty {
                    Section("Tags") {
                        ForEach(conversation.tags, id: \.self) { tag in
                            Text(tag)
                        }
                    }
                }
                
                Section("Statistics") {
                    LabeledContent("User Messages", 
                                 value: "\(conversation.messages.filter { $0.role == .user }.count)")
                    LabeledContent("Assistant Messages", 
                                 value: "\(conversation.messages.filter { $0.role == .assistant }.count)")
                    LabeledContent("Estimated Tokens", 
                                 value: "\(conversation.messages.reduce(0) { $0 + $1.content.count / 4 })")
                }
            }
            .navigationTitle("Conversation Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}