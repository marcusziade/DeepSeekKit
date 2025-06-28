import SwiftUI
import DeepSeekKit

struct ModelSelector: View {
    @StateObject private var client = DeepSeekClient()
    @State private var selectedModel: DeepSeekModel = .chat
    @State private var messages: [ChatMessage] = []
    @State private var currentMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Model Switcher
                Picker("Model", selection: $selectedModel) {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                        .tag(DeepSeekModel.chat)
                    Label("Reasoner", systemImage: "brain")
                        .tag(DeepSeekModel.reasoner)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedModel) { _ in
                    // Add a system message when switching models
                    let modelName = selectedModel == .chat ? "Chat" : "Reasoner"
                    messages.append(ChatMessage(
                        role: "system",
                        content: "Switched to \(modelName) model"
                    ))
                }
                
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(messages.indices, id: \.self) { index in
                                MessageBubble(message: messages[index])
                                    .id(index)
                            }
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Thinking with \(selectedModel.rawValue)...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(messages.count - 1, anchor: .bottom)
                        }
                    }
                }
                
                // Input Area
                HStack {
                    TextField("Type a message...", text: $currentMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(currentMessage.isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("Model Switching Demo")
        }
    }
    
    private func sendMessage() {
        let userMessage = currentMessage
        currentMessage = ""
        
        messages.append(ChatMessage(role: "user", content: userMessage))
        
        Task {
            isLoading = true
            
            do {
                let response = try await client.chat(
                    messages: messages.map { message in
                        message.role == "user" ? .user(message.content) : .assistant(message.content)
                    },
                    model: selectedModel
                )
                
                if let reply = response.choices.first?.message {
                    var assistantMessage = ChatMessage(
                        role: "assistant",
                        content: reply.content ?? ""
                    )
                    
                    // Include reasoning if available
                    if let reasoning = reply.reasoningContent {
                        assistantMessage.reasoning = reasoning
                    }
                    
                    messages.append(assistantMessage)
                }
            } catch {
                messages.append(ChatMessage(
                    role: "system",
                    content: "Error: \(error.localizedDescription)"
                ))
            }
            
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                if message.role == "system" {
                    Text(message.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text(message.content)
                        .padding(10)
                        .background(backgroundColor)
                        .foregroundColor(foregroundColor)
                        .cornerRadius(10)
                    
                    if let reasoning = message.reasoning {
                        DisclosureGroup("Show reasoning") {
                            Text(reasoning)
                                .font(.caption)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .font(.caption)
                    }
                }
            }
            
            if message.role == "assistant" {
                Spacer()
            }
        }
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case "user": return .blue
        case "assistant": return .gray.opacity(0.2)
        default: return .clear
        }
    }
    
    private var foregroundColor: Color {
        message.role == "user" ? .white : .primary
    }
}

struct ChatMessage {
    let role: String
    let content: String
    var reasoning: String?
}