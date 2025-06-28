import SwiftUI
import DeepSeekKit

// Adding typing indicators during streaming
struct StreamingWithIndicatorView: View {
    @StateObject private var chatModel = ChatWithIndicatorModel()
    @State private var inputText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Image(systemName: "message.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("AI Assistant")
                    .font(.headline)
                Spacer()
                if chatModel.isStreaming {
                    StreamingStatusBadge()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            Divider()
            
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(chatModel.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                        
                        // Typing indicator
                        if chatModel.showTypingIndicator {
                            TypingIndicatorView(style: chatModel.indicatorStyle)
                                .id("typing")
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding()
                    .animation(.easeInOut, value: chatModel.showTypingIndicator)
                }
                .onChange(of: chatModel.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(chatModel.showTypingIndicator ? "typing" : chatModel.messages.last?.id)
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack {
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(chatModel.isStreaming)
                
                Button(action: {
                    Task {
                        await chatModel.sendMessage(inputText)
                        inputText = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(inputText.isEmpty || chatModel.isStreaming ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || chatModel.isStreaming)
            }
            .padding()
        }
    }
}

// Chat model with typing indicator management
@MainActor
class ChatWithIndicatorModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isStreaming = false
    @Published var showTypingIndicator = false
    @Published var indicatorStyle: TypingIndicatorView.Style = .dots
    
    private let client = DeepSeekClient()
    private var currentStreamingMessage: Message?
    
    struct Message: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        let timestamp = Date()
        var isComplete = true
    }
    
    func sendMessage(_ content: String) async {
        // Add user message
        messages.append(Message(role: "user", content: content))
        
        // Start streaming with indicator
        await streamResponseWithIndicator(for: content)
    }
    
    private func streamResponseWithIndicator(for prompt: String) async {
        isStreaming = true
        showTypingIndicator = true
        
        // Vary indicator style based on expected response length
        indicatorStyle = prompt.count > 50 ? .wave : .dots
        
        // Small delay to show indicator before content starts
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Create assistant message
        var assistantMessage = Message(
            role: "assistant",
            content: "",
            isComplete: false
        )
        
        do {
            var hasContent = false
            
            for try await chunk in client.streamMessage(prompt) {
                if let content = chunk.choices.first?.delta.content {
                    // Hide typing indicator once content starts arriving
                    if !hasContent && !content.isEmpty {
                        showTypingIndicator = false
                        messages.append(assistantMessage)
                        currentStreamingMessage = assistantMessage
                        hasContent = true
                    }
                    
                    // Update message content
                    if hasContent,
                       let index = messages.firstIndex(where: { $0.id == assistantMessage.id }) {
                        messages[index].content += content
                    } else {
                        assistantMessage.content += content
                    }
                }
            }
            
            // Mark as complete
            if let index = messages.firstIndex(where: { $0.id == assistantMessage.id }) {
                messages[index].isComplete = true
            }
            
        } catch {
            showTypingIndicator = false
            
            // Add error message if no content was added
            if !messages.contains(where: { $0.id == assistantMessage.id }) {
                assistantMessage.content = "Sorry, an error occurred: \(error.localizedDescription)"
                messages.append(assistantMessage)
            }
        }
        
        isStreaming = false
        showTypingIndicator = false
        currentStreamingMessage = nil
    }
}

// Various typing indicator styles
struct TypingIndicatorView: View {
    let style: Style
    @State private var animationPhase = 0.0
    
    enum Style {
        case dots
        case wave
        case pulse
        case ellipsis
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundColor(.gray)
                .font(.title2)
            
            HStack(spacing: 4) {
                switch style {
                case .dots:
                    dotsIndicator
                case .wave:
                    waveIndicator
                case .pulse:
                    pulseIndicator
                case .ellipsis:
                    ellipsisIndicator
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animationPhase = 1.0
            }
        }
    }
    
    var dotsIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == 1.0 ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
    }
    
    var waveIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 3, height: animationPhase == 1.0 ? 20 : 10)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animationPhase
                    )
            }
        }
    }
    
    var pulseIndicator: some View {
        Circle()
            .fill(Color.gray.opacity(0.6))
            .frame(width: 40, height: 40)
            .scaleEffect(animationPhase)
            .opacity(2 - animationPhase)
            .overlay(
                Circle()
                    .fill(Color.gray)
                    .frame(width: 20, height: 20)
            )
    }
    
    var ellipsisIndicator: some View {
        Text("...")
            .font(.title3)
            .foregroundColor(.gray)
            .opacity(animationPhase)
    }
}

// Message row component
struct MessageRow: View {
    let message: ChatWithIndicatorModel.Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Image(systemName: message.role == "user" ? "person.circle.fill" : "cpu")
                .font(.title2)
                .foregroundColor(message.role == "user" ? .blue : .green)
            
            VStack(alignment: .leading, spacing: 4) {
                // Role label
                Text(message.role.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Message content
                Text(message.content)
                    .textSelection(.enabled)
                
                // Timestamp and status
                HStack {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if !message.isComplete {
                        Label("Streaming", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
        }
    }
}

// Streaming status badge
struct StreamingStatusBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .opacity(isAnimating ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            
            Text("Live")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.2))
        .cornerRadius(12)
        .onAppear { isAnimating = true }
    }
}