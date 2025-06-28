import SwiftUI
import DeepSeekKit

struct ConversationView: View {
    @StateObject private var manager = ConversationManager(
        apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
    )
    @State private var inputText = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Conversation history
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(manager.messages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(message: message)
                                .id(index)
                        }
                        
                        if isLoading {
                            TypingIndicator()
                                .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: manager.messages.count) { _ in
                    // Auto-scroll to bottom
                    withAnimation {
                        proxy.scrollTo(manager.messages.count - 1, anchor: .bottom)
                    }
                }
                .onChange(of: isLoading) { loading in
                    if loading {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(inputText.isEmpty || isLoading ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    manager.setupNewConversation()
                }
            }
        }
    }
    
    private func sendMessage() {
        let message = inputText
        inputText = ""
        isLoading = true
        
        Task {
            do {
                _ = try await manager.sendMessage(message)
            } catch {
                // Handle error
                print("Error: \(error)")
            }
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .system ? "System" : 
                     message.role == .user ? "You" : "Assistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
        case .system:
            return Color.orange.opacity(0.2)
        case .user:
            return Color.blue
        case .assistant:
            return Color.gray.opacity(0.2)
        case .function:
            return Color.green.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        message.role == .user ? .white : .primary
    }
}

struct TypingIndicator: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationAmount)
                    .opacity(2 - animationAmount)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationAmount
                    )
            }
        }
        .onAppear {
            animationAmount = 2.0
        }
    }
}