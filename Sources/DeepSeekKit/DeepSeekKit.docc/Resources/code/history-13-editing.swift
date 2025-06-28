import SwiftUI
import DeepSeekKit

// Message editing and regeneration support
class EditableConversationManager: ObservableObject {
    @Published var messages: [EditableMessage] = []
    @Published var isRegenerating = false
    
    private let client: DeepSeekClient
    
    struct EditableMessage: Identifiable {
        let id = UUID()
        var message: Message
        var isEditing = false
        var editedContent: String = ""
        var variations: [String] = [] // Alternative responses
        var selectedVariationIndex: Int = 0
    }
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
        setupInitialMessage()
    }
    
    private func setupInitialMessage() {
        let systemMessage = EditableMessage(
            message: Message(
                role: .system,
                content: "You are a helpful AI assistant. Users can edit messages and regenerate responses."
            )
        )
        messages.append(systemMessage)
    }
    
    // MARK: - Message Management
    
    func addUserMessage(_ content: String) {
        let message = EditableMessage(message: Message(role: .user, content: content))
        messages.append(message)
    }
    
    func addAssistantMessage(_ content: String) {
        let message = EditableMessage(
            message: Message(role: .assistant, content: content),
            variations: [content] // Store original as first variation
        )
        messages.append(message)
    }
    
    // MARK: - Editing
    
    func startEditing(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        messages[index].isEditing = true
        messages[index].editedContent = messages[index].message.content
    }
    
    func saveEdit(messageId: UUID) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        let editedMessage = messages[index]
        messages[index].message.content = editedMessage.editedContent
        messages[index].isEditing = false
        
        // If editing a user message, regenerate all subsequent responses
        if editedMessage.message.role == .user {
            await regenerateFrom(index: index)
        }
    }
    
    func cancelEdit(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        messages[index].isEditing = false
        messages[index].editedContent = ""
    }
    
    // MARK: - Regeneration
    
    func regenerateResponse(at index: Int) async {
        guard index > 0, 
              index < messages.count,
              messages[index].message.role == .assistant else { return }
        
        isRegenerating = true
        
        do {
            // Get conversation up to the previous user message
            let contextMessages = messages[0..<index].map { $0.message }
            
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: contextMessages,
                temperature: 0.8 // Higher temperature for variation
            )
            
            let response = try await client.chat.completions(request)
            if let newContent = response.choices.first?.message.content {
                // Add as new variation
                messages[index].variations.append(newContent)
                messages[index].selectedVariationIndex = messages[index].variations.count - 1
                messages[index].message.content = newContent
            }
        } catch {
            print("Regeneration error: \(error)")
        }
        
        isRegenerating = false
    }
    
    func regenerateFrom(index: Int) async {
        // Remove all messages after the edited one
        let messagesToRemove = messages.count - index - 1
        if messagesToRemove > 0 {
            messages.removeLast(messagesToRemove)
        }
        
        // If the last message is from user, generate a response
        if messages.last?.message.role == .user {
            await generateResponse()
        }
    }
    
    private func generateResponse() async {
        isRegenerating = true
        
        do {
            let contextMessages = messages.map { $0.message }
            
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: contextMessages,
                temperature: 0.7
            )
            
            let response = try await client.chat.completions(request)
            if let content = response.choices.first?.message.content {
                addAssistantMessage(content)
            }
        } catch {
            print("Generation error: \(error)")
        }
        
        isRegenerating = false
    }
    
    // MARK: - Variation Management
    
    func selectVariation(messageId: UUID, variationIndex: Int) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              variationIndex < messages[index].variations.count else { return }
        
        messages[index].selectedVariationIndex = variationIndex
        messages[index].message.content = messages[index].variations[variationIndex]
    }
}

// MARK: - UI Components

struct EditableConversationView: View {
    @StateObject private var manager: EditableConversationManager
    @State private var inputText = ""
    @FocusState private var focusedMessageId: UUID?
    
    init(apiKey: String) {
        _manager = StateObject(wrappedValue: EditableConversationManager(apiKey: apiKey))
    }
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.messages) { editableMessage in
                            EditableMessageView(
                                editableMessage: editableMessage,
                                manager: manager,
                                focusedMessageId: $focusedMessageId
                            )
                            .id(editableMessage.id)
                        }
                        
                        if manager.isRegenerating {
                            RegeneratingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: manager.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(manager.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(manager.isRegenerating)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(inputText.isEmpty || manager.isRegenerating)
            }
            .padding()
        }
        .navigationTitle("Editable Conversation")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        let message = inputText
        inputText = ""
        
        manager.addUserMessage(message)
        
        Task {
            await manager.generateResponse()
        }
    }
}

struct EditableMessageView: View {
    let editableMessage: EditableConversationManager.EditableMessage
    let manager: EditableConversationManager
    @FocusState.Binding var focusedMessageId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message header
            HStack {
                Text(editableMessage.message.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Action buttons
                if editableMessage.message.role != .system {
                    MessageActionsMenu(
                        editableMessage: editableMessage,
                        manager: manager
                    )
                }
            }
            
            // Message content
            if editableMessage.isEditing {
                VStack {
                    TextEditor(text: Binding(
                        get: { editableMessage.editedContent },
                        set: { newValue in
                            if let index = manager.messages.firstIndex(where: { $0.id == editableMessage.id }) {
                                manager.messages[index].editedContent = newValue
                            }
                        }
                    ))
                    .focused($focusedMessageId, equals: editableMessage.id)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    HStack {
                        Button("Cancel") {
                            manager.cancelEdit(messageId: editableMessage.id)
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Save") {
                            Task {
                                await manager.saveEdit(messageId: editableMessage.id)
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .font(.caption)
                }
            } else {
                Text(editableMessage.message.content)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(backgroundColorForRole(editableMessage.message.role))
                    .cornerRadius(12)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = editableMessage.message.content
                        }) {
                            Label("Copy", systemImage: "doc.on.clipboard")
                        }
                        
                        if editableMessage.message.role != .system {
                            Button(action: {
                                manager.startEditing(messageId: editableMessage.id)
                                focusedMessageId = editableMessage.id
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
            }
            
            // Variation selector (for assistant messages with multiple variations)
            if editableMessage.message.role == .assistant && 
               editableMessage.variations.count > 1 {
                VariationSelector(
                    editableMessage: editableMessage,
                    manager: manager
                )
            }
        }
    }
    
    private func backgroundColorForRole(_ role: MessageRole) -> Color {
        switch role {
        case .system: return Color.orange.opacity(0.2)
        case .user: return Color.blue.opacity(0.2)
        case .assistant: return Color.gray.opacity(0.2)
        case .function: return Color.green.opacity(0.2)
        }
    }
}

struct MessageActionsMenu: View {
    let editableMessage: EditableConversationManager.EditableMessage
    let manager: EditableConversationManager
    
    var body: some View {
        Menu {
            Button(action: {
                manager.startEditing(messageId: editableMessage.id)
            }) {
                Label("Edit", systemImage: "pencil")
            }
            
            if editableMessage.message.role == .assistant {
                Button(action: {
                    Task {
                        if let index = manager.messages.firstIndex(where: { $0.id == editableMessage.id }) {
                            await manager.regenerateResponse(at: index)
                        }
                    }
                }) {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
            }
            
            Button(action: {
                UIPasteboard.general.string = editableMessage.message.content
            }) {
                Label("Copy", systemImage: "doc.on.clipboard")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct VariationSelector: View {
    let editableMessage: EditableConversationManager.EditableMessage
    let manager: EditableConversationManager
    
    var body: some View {
        HStack {
            Text("Variation \(editableMessage.selectedVariationIndex + 1) of \(editableMessage.variations.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Button(action: selectPreviousVariation) {
                    Image(systemName: "chevron.left")
                }
                .disabled(editableMessage.selectedVariationIndex == 0)
                
                Button(action: selectNextVariation) {
                    Image(systemName: "chevron.right")
                }
                .disabled(editableMessage.selectedVariationIndex >= editableMessage.variations.count - 1)
            }
            .font(.caption)
        }
        .padding(.horizontal)
    }
    
    private func selectPreviousVariation() {
        let newIndex = editableMessage.selectedVariationIndex - 1
        manager.selectVariation(messageId: editableMessage.id, variationIndex: newIndex)
    }
    
    private func selectNextVariation() {
        let newIndex = editableMessage.selectedVariationIndex + 1
        manager.selectVariation(messageId: editableMessage.id, variationIndex: newIndex)
    }
}

struct RegeneratingIndicator: View {
    @State private var dots = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            Text("Regenerating" + String(repeating: ".", count: dots))
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView()
                .scaleEffect(0.8)
        }
        .onReceive(timer) { _ in
            dots = (dots + 1) % 4
        }
    }
}