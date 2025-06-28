import SwiftUI
import DeepSeekKit

// A complete streaming chat view with proper state management
struct StreamingChatView: View {
    @StateObject private var viewModel = StreamingChatViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // Show streaming indicator
                            if viewModel.isStreaming {
                                StreamingIndicator()
                                    .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.isStreaming ? "streaming" : viewModel.messages.last?.id)
                        }
                    }
                }
                
                Divider()
                
                // Input area
                MessageInputView(
                    text: $messageText,
                    isStreaming: viewModel.isStreaming,
                    onSend: {
                        Task {
                            await viewModel.sendMessage(messageText)
                            messageText = ""
                        }
                    }
                )
                .focused($isInputFocused)
            }
            .navigationTitle("Streaming Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        viewModel.clearMessages()
                    }
                }
            }
        }
    }
}

// View Model with proper state management
@MainActor
class StreamingChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var streamingMessageId: UUID?
    
    private let client = DeepSeekClient()
    private var streamTask: Task<Void, Never>?
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        let timestamp = Date()
        var isStreaming = false
    }
    
    func sendMessage(_ content: String) async {
        // Add user message
        let userMessage = ChatMessage(role: "user", content: content)
        messages.append(userMessage)
        
        // Start streaming response
        await streamResponse(for: content)
    }
    
    func streamResponse(for prompt: String) async {
        isStreaming = true
        
        // Create placeholder for streaming message
        var assistantMessage = ChatMessage(
            role: "assistant",
            content: "",
            isStreaming: true
        )
        streamingMessageId = assistantMessage.id
        messages.append(assistantMessage)
        
        do {
            // Stream the response
            for try await chunk in client.streamMessage(prompt) {
                if let content = chunk.choices.first?.delta.content {
                    // Update the streaming message
                    if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                        messages[index].content += content
                    }
                }
            }
            
            // Mark as complete
            if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                messages[index].isStreaming = false
            }
        } catch {
            // Handle error
            if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                messages[index].content = "Error: \(error.localizedDescription)"
                messages[index].isStreaming = false
            }
        }
        
        isStreaming = false
        streamingMessageId = nil
    }
    
    func clearMessages() {
        messages.removeAll()
        streamTask?.cancel()
        isStreaming = false
    }
}

// Message bubble component
struct MessageBubble: View {
    let message: StreamingChatViewModel.ChatMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == "user" ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .cornerRadius(16)
                
                if message.isStreaming {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis")
                            .font(.caption2)
                        Text("Streaming...")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            if message.role == "assistant" {
                Spacer()
            }
        }
    }
}

// Streaming indicator
struct StreamingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// Message input component
struct MessageInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack {
            TextField("Type a message...", text: $text)
                .textFieldStyle(.roundedBorder)
                .disabled(isStreaming)
                .onSubmit {
                    if !text.isEmpty && !isStreaming {
                        onSend()
                    }
                }
            
            Button(action: onSend) {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(text.isEmpty || isStreaming)
        }
        .padding()
    }
}