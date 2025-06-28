import SwiftUI
import DeepSeekKit

// Implementing smooth text animation for streaming
struct AnimatedStreamingView: View {
    @StateObject private var animator = StreamAnimator()
    @State private var prompt = ""
    @State private var selectedAnimation: AnimationType = .typewriter
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Smooth Streaming Animations")
                .font(.largeTitle)
                .bold()
            
            // Animation selector
            AnimationSelectorView(selectedAnimation: $selectedAnimation)
            
            // Animated message display
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(animator.messages) { message in
                            AnimatedMessageView(
                                message: message,
                                animationType: selectedAnimation
                            )
                            .id(message.id)
                        }
                        
                        if animator.isStreaming {
                            StreamingAnimationView(type: selectedAnimation)
                                .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: animator.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(animator.isStreaming ? "streaming" : animator.messages.last?.id)
                    }
                }
            }
            
            // Animation controls
            AnimationControlsView(animator: animator)
            
            // Input
            HStack {
                TextField("Enter message", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                
                Button("Send") {
                    Task {
                        await animator.streamWithAnimation(
                            prompt: prompt,
                            animationType: selectedAnimation
                        )
                        prompt = ""
                    }
                }
                .disabled(prompt.isEmpty || animator.isStreaming)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Animation types
enum AnimationType: String, CaseIterable {
    case typewriter = "Typewriter"
    case fade = "Fade In"
    case slide = "Slide"
    case wave = "Wave"
    case cascade = "Cascade"
    case glitch = "Glitch"
    
    var icon: String {
        switch self {
        case .typewriter: return "keyboard"
        case .fade: return "sparkle"
        case .slide: return "arrow.right.circle"
        case .wave: return "waveform"
        case .cascade: return "square.stack.3d.down.right"
        case .glitch: return "exclamationmark.triangle"
        }
    }
}

// Stream animator
@MainActor
class StreamAnimator: ObservableObject {
    @Published var messages: [AnimatedMessage] = []
    @Published var isStreaming = false
    @Published var animationSpeed: Double = 1.0
    @Published var enableSoundEffects = true
    
    private let client = DeepSeekClient()
    private var animationTask: Task<Void, Never>?
    
    struct AnimatedMessage: Identifiable {
        let id = UUID()
        let role: String
        var fullContent: String
        var displayedContent: String
        var animationProgress: Double = 0
        var characterRevealIndex: Int = 0
        var wordRevealIndex: Int = 0
        let timestamp = Date()
    }
    
    func streamWithAnimation(prompt: String, animationType: AnimationType) async {
        isStreaming = true
        
        // Add user message (instant display)
        let userMessage = AnimatedMessage(
            role: "user",
            fullContent: prompt,
            displayedContent: prompt,
            animationProgress: 1.0
        )
        messages.append(userMessage)
        
        // Create assistant message
        var assistantMessage = AnimatedMessage(
            role: "assistant",
            fullContent: "",
            displayedContent: ""
        )
        let messageId = assistantMessage.id
        messages.append(assistantMessage)
        
        // Stream and animate
        await performAnimatedStream(
            messageId: messageId,
            prompt: prompt,
            animationType: animationType
        )
        
        isStreaming = false
    }
    
    private func performAnimatedStream(
        messageId: UUID,
        prompt: String,
        animationType: AnimationType
    ) async {
        var contentBuffer = ""
        var chunkQueue: [String] = []
        var isAnimating = false
        
        // Start animation task
        animationTask = Task {
            while !Task.isCancelled {
                if !chunkQueue.isEmpty && !isAnimating {
                    isAnimating = true
                    let chunk = chunkQueue.removeFirst()
                    await animateChunk(
                        messageId: messageId,
                        chunk: chunk,
                        animationType: animationType
                    )
                    isAnimating = false
                }
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        do {
            for try await chunk in client.streamMessage(prompt) {
                if let content = chunk.choices.first?.delta.content {
                    contentBuffer += content
                    chunkQueue.append(content)
                    
                    // Update full content immediately
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].fullContent = contentBuffer
                    }
                }
            }
            
            // Wait for animation to complete
            while !chunkQueue.isEmpty {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
            // Ensure full content is displayed
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].displayedContent = messages[index].fullContent
                messages[index].animationProgress = 1.0
            }
        } catch {
            print("Stream error: \(error)")
        }
        
        animationTask?.cancel()
    }
    
    private func animateChunk(
        messageId: UUID,
        chunk: String,
        animationType: AnimationType
    ) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        switch animationType {
        case .typewriter:
            await animateTypewriter(index: index, chunk: chunk)
        case .fade:
            await animateFade(index: index, chunk: chunk)
        case .slide:
            await animateSlide(index: index, chunk: chunk)
        case .wave:
            await animateWave(index: index, chunk: chunk)
        case .cascade:
            await animateCascade(index: index, chunk: chunk)
        case .glitch:
            await animateGlitch(index: index, chunk: chunk)
        }
    }
    
    private func animateTypewriter(index: Int, chunk: String) async {
        for char in chunk {
            messages[index].displayedContent.append(char)
            
            // Play sound effect
            if enableSoundEffects {
                playTypewriterSound()
            }
            
            // Variable speed for more natural feel
            let baseDelay = 30_000_000 / animationSpeed // 30ms base
            let variation = Double.random(in: 0.5...1.5)
            let delay = UInt64(Double(baseDelay) * variation)
            
            try? await Task.sleep(nanoseconds: delay)
        }
    }
    
    private func animateFade(index: Int, chunk: String) async {
        let words = chunk.split(separator: " ").map(String.init)
        
        for word in words {
            withAnimation(.easeIn(duration: 0.3 / animationSpeed)) {
                if !messages[index].displayedContent.isEmpty {
                    messages[index].displayedContent += " "
                }
                messages[index].displayedContent += word
            }
            
            try? await Task.sleep(nanoseconds: UInt64(100_000_000 / animationSpeed))
        }
    }
    
    private func animateSlide(index: Int, chunk: String) async {
        let words = chunk.split(separator: " ").map(String.init)
        
        for word in words {
            withAnimation(.spring(response: 0.3 / animationSpeed, dampingFraction: 0.8)) {
                if !messages[index].displayedContent.isEmpty {
                    messages[index].displayedContent += " "
                }
                messages[index].displayedContent += word
            }
            
            try? await Task.sleep(nanoseconds: UInt64(80_000_000 / animationSpeed))
        }
    }
    
    private func animateWave(index: Int, chunk: String) async {
        for (i, char) in chunk.enumerated() {
            withAnimation(.easeInOut(duration: 0.5 / animationSpeed).delay(Double(i) * 0.02)) {
                messages[index].displayedContent.append(char)
            }
            
            try? await Task.sleep(nanoseconds: UInt64(20_000_000 / animationSpeed))
        }
    }
    
    private func animateCascade(index: Int, chunk: String) async {
        let lines = chunk.split(separator: "\n").map(String.init)
        
        for line in lines {
            withAnimation(.spring(response: 0.5 / animationSpeed)) {
                if !messages[index].displayedContent.isEmpty && !line.isEmpty {
                    messages[index].displayedContent += "\n"
                }
                messages[index].displayedContent += line
            }
            
            try? await Task.sleep(nanoseconds: UInt64(200_000_000 / animationSpeed))
        }
    }
    
    private func animateGlitch(index: Int, chunk: String) async {
        let glitchChars = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        
        for finalChar in chunk {
            // Glitch effect
            for _ in 0..<3 {
                let glitchChar = glitchChars.randomElement() ?? finalChar
                messages[index].displayedContent.append(glitchChar)
                try? await Task.sleep(nanoseconds: 20_000_000)
                _ = messages[index].displayedContent.popLast()
            }
            
            // Show final character
            messages[index].displayedContent.append(finalChar)
            try? await Task.sleep(nanoseconds: UInt64(50_000_000 / animationSpeed))
        }
    }
    
    private func playTypewriterSound() {
        // In a real app, play a subtle typewriter sound
        // Using system haptics as a substitute
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
}

// UI Components
struct AnimationSelectorView: View {
    @Binding var selectedAnimation: AnimationType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AnimationType.allCases, id: \.self) { type in
                    AnimationTypeButton(
                        type: type,
                        isSelected: selectedAnimation == type,
                        action: { selectedAnimation = type }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AnimationTypeButton: View {
    let type: AnimationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
}

struct AnimatedMessageView: View {
    let message: StreamAnimator.AnimatedMessage
    let animationType: AnimationType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.role.capitalized)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .topLeading) {
                // Hidden full text for layout
                Text(message.fullContent)
                    .opacity(0)
                    .padding()
                
                // Animated displayed text
                AnimatedTextView(
                    text: message.displayedContent,
                    animationType: animationType
                )
                .padding()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            if message.displayedContent.count < message.fullContent.count {
                ProgressView(value: Double(message.displayedContent.count),
                           total: Double(message.fullContent.count))
                    .tint(.blue)
            }
        }
    }
}

struct AnimatedTextView: View {
    let text: String
    let animationType: AnimationType
    
    var body: some View {
        switch animationType {
        case .typewriter, .fade, .slide:
            Text(text)
                .animation(.easeInOut, value: text)
        case .wave:
            WaveTextView(text: text)
        case .cascade:
            Text(text)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
        case .glitch:
            GlitchTextView(text: text)
        }
    }
}

struct WaveTextView: View {
    let text: String
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .offset(y: sin(animationAmount + Double(index) * 0.2) * 2)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: animationAmount
                    )
            }
        }
        .onAppear {
            animationAmount = .pi * 2
        }
    }
}

struct GlitchTextView: View {
    let text: String
    @State private var glitchOffset = CGSize.zero
    @State private var glitchOpacity = 1.0
    
    var body: some View {
        ZStack {
            Text(text)
                .foregroundColor(.red)
                .offset(glitchOffset)
                .opacity(glitchOpacity * 0.5)
            
            Text(text)
                .foregroundColor(.blue)
                .offset(x: -glitchOffset.width, y: -glitchOffset.height)
                .opacity(glitchOpacity * 0.5)
            
            Text(text)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if Bool.random() {
                    glitchOffset = CGSize(
                        width: CGFloat.random(in: -2...2),
                        height: CGFloat.random(in: -2...2)
                    )
                    glitchOpacity = Double.random(in: 0.8...1.0)
                } else {
                    glitchOffset = .zero
                    glitchOpacity = 1.0
                }
            }
        }
    }
}

struct StreamingAnimationView: View {
    let type: AnimationType
    
    var body: some View {
        HStack {
            switch type {
            case .typewriter:
                TypewriterCursor()
            case .fade:
                FadingDots()
            case .slide:
                SlidingIndicator()
            case .wave:
                WaveIndicator()
            case .cascade:
                CascadingDots()
            case .glitch:
                GlitchIndicator()
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TypewriterCursor: View {
    @State private var isBlinking = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Typing")
                .foregroundColor(.blue)
            Rectangle()
                .fill(Color.blue)
                .frame(width: 2, height: 16)
                .opacity(isBlinking ? 0 : 1)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: isBlinking)
        }
        .onAppear { isBlinking = true }
    }
}

struct FadingDots: View {
    @State private var opacity: [Double] = [0.3, 0.3, 0.3]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .opacity(opacity[i])
            }
        }
        .onAppear {
            animateDots()
        }
    }
    
    func animateDots() {
        for i in 0..<3 {
            withAnimation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2)) {
                opacity[i] = 1.0
            }
        }
    }
}

struct AnimationControlsView: View {
    @ObservedObject var animator: StreamAnimator
    
    var body: some View {
        VStack(spacing: 12) {
            // Speed control
            HStack {
                Text("Animation Speed")
                Slider(value: $animator.animationSpeed, in: 0.5...2.0)
                Text("\(String(format: "%.1f", animator.animationSpeed))x")
                    .frame(width: 40)
            }
            
            // Sound toggle
            Toggle("Sound Effects", isOn: $animator.enableSoundEffects)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// Additional animation indicators
struct SlidingIndicator: View {
    @State private var offset: CGFloat = -20
    
    var body: some View {
        HStack {
            Text("Streaming")
                .foregroundColor(.blue)
            Image(systemName: "arrow.right")
                .offset(x: offset)
                .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: offset)
        }
        .onAppear { offset = 20 }
    }
}

struct WaveIndicator: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                Capsule()
                    .fill(Color.blue)
                    .frame(width: 3, height: 20)
                    .scaleEffect(y: sin(Double(i) * .pi / 4) * 0.5 + 0.5)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.1), value: i)
            }
        }
    }
}

struct CascadingDots: View {
    @State private var offsets: [CGFloat] = [0, 0, 0]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .offset(y: offsets[i])
            }
        }
        .onAppear {
            for i in 0..<3 {
                withAnimation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2)) {
                    offsets[i] = 15
                }
            }
        }
    }
}

struct GlitchIndicator: View {
    @State private var text = "Streaming"
    let glitchChars = "!@#$%^&*"
    
    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.blue)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    if Bool.random() && Bool.random() {
                        var chars = Array(text)
                        let index = Int.random(in: 0..<chars.count)
                        chars[index] = glitchChars.randomElement() ?? chars[index]
                        text = String(chars)
                    } else {
                        text = "Streaming"
                    }
                }
            }
    }
}