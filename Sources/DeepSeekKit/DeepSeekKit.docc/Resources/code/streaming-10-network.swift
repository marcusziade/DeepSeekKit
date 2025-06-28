import SwiftUI
import DeepSeekKit
import Network

// Handling network interruptions gracefully during streaming
struct NetworkResilientStreamingView: View {
    @StateObject private var networkStream = NetworkResilientStream()
    @State private var prompt = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with network status
            NetworkStatusHeader(monitor: networkStream.networkMonitor)
            
            // Connection quality indicator
            ConnectionQualityView(quality: networkStream.connectionQuality)
            
            // Message display
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(networkStream.messages) { message in
                        NetworkAwareMessageView(message: message)
                    }
                }
                .padding()
            }
            
            // Network interruption recovery
            if networkStream.hasPartialContent {
                PartialContentRecoveryView(stream: networkStream)
            }
            
            // Input area
            HStack {
                TextField("Enter message", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!networkStream.isNetworkAvailable)
                
                Button("Send") {
                    Task {
                        await networkStream.sendWithNetworkResilience(prompt)
                        prompt = ""
                    }
                }
                .disabled(prompt.isEmpty || networkStream.isStreaming || !networkStream.isNetworkAvailable)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Network resilient streaming handler
@MainActor
class NetworkResilientStream: ObservableObject {
    @Published var messages: [NetworkMessage] = []
    @Published var isStreaming = false
    @Published var isNetworkAvailable = true
    @Published var connectionQuality: ConnectionQuality = .good
    @Published var hasPartialContent = false
    
    let networkMonitor = NetworkMonitor()
    private let client = DeepSeekClient()
    private var currentStreamTask: Task<Void, Never>?
    private var partialMessage: NetworkMessage?
    
    struct NetworkMessage: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        var status: MessageStatus
        var metadata: StreamMetadata
        
        enum MessageStatus {
            case complete
            case streaming
            case partial(savedAt: Date, lastChunk: Int)
            case failed(reason: String)
            case resumed
        }
        
        struct StreamMetadata {
            var startTime: Date
            var lastUpdateTime: Date
            var chunkCount: Int
            var bytesSaved: Int
            var networkInterruptions: Int
        }
    }
    
    enum ConnectionQuality {
        case excellent
        case good
        case fair
        case poor
        case offline
    }
    
    init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path: path)
            }
        }
        networkMonitor.start()
    }
    
    private func updateNetworkStatus(path: NWPath) {
        isNetworkAvailable = path.status == .satisfied
        
        // Determine connection quality
        if !isNetworkAvailable {
            connectionQuality = .offline
        } else if path.isExpensive {
            connectionQuality = .fair
        } else if path.isConstrained {
            connectionQuality = .poor
        } else {
            connectionQuality = .good
        }
        
        // Handle ongoing stream if network changes
        if !isNetworkAvailable && isStreaming {
            handleNetworkLoss()
        } else if isNetworkAvailable && hasPartialContent {
            // Offer to resume
            objectWillChange.send()
        }
    }
    
    func sendWithNetworkResilience(_ prompt: String) async {
        guard isNetworkAvailable else {
            addSystemMessage("Cannot send message: No network connection")
            return
        }
        
        // Add user message
        let userMessage = NetworkMessage(
            role: "user",
            content: prompt,
            status: .complete,
            metadata: NetworkMessage.StreamMetadata(
                startTime: Date(),
                lastUpdateTime: Date(),
                chunkCount: 1,
                bytesSaved: prompt.count,
                networkInterruptions: 0
            )
        )
        messages.append(userMessage)
        
        // Start streaming
        await streamWithResilience(prompt: prompt)
    }
    
    private func streamWithResilience(prompt: String, resumeFrom: NetworkMessage? = nil) async {
        isStreaming = true
        
        var message = resumeFrom ?? NetworkMessage(
            role: "assistant",
            content: "",
            status: .streaming,
            metadata: NetworkMessage.StreamMetadata(
                startTime: Date(),
                lastUpdateTime: Date(),
                chunkCount: 0,
                bytesSaved: 0,
                networkInterruptions: 0
            )
        )
        
        if resumeFrom == nil {
            messages.append(message)
        }
        
        let messageId = message.id
        
        currentStreamTask = Task {
            await performResilientStream(prompt: prompt, messageId: messageId)
        }
        
        await currentStreamTask?.value
        isStreaming = false
    }
    
    private func performResilientStream(prompt: String, messageId: UUID) async {
        var lastSuccessfulChunk = 0
        var contentBuffer = ""
        
        do {
            for try await chunk in client.streamMessage(prompt) {
                // Check network status
                guard isNetworkAvailable else {
                    throw NetworkStreamError.connectionLost(
                        afterChunk: lastSuccessfulChunk,
                        partialContent: contentBuffer
                    )
                }
                
                // Process chunk
                if let content = chunk.choices.first?.delta.content {
                    contentBuffer += content
                    lastSuccessfulChunk += 1
                    
                    // Update message
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].content = contentBuffer
                        messages[index].metadata.chunkCount = lastSuccessfulChunk
                        messages[index].metadata.lastUpdateTime = Date()
                        messages[index].metadata.bytesSaved = contentBuffer.count
                        
                        // Periodic saves for long streams
                        if lastSuccessfulChunk % 10 == 0 {
                            savePartialContent(messageId: messageId, content: contentBuffer)
                        }
                    }
                }
                
                // Check for completion
                if chunk.choices.first?.finishReason != nil {
                    markMessageComplete(messageId: messageId)
                    hasPartialContent = false
                    partialMessage = nil
                }
            }
        } catch NetworkStreamError.connectionLost(let chunk, let content) {
            handlePartialStream(messageId: messageId, lastChunk: chunk, content: content)
        } catch {
            handleStreamError(messageId: messageId, error: error)
        }
    }
    
    private func handleNetworkLoss() {
        currentStreamTask?.cancel()
        
        // Find streaming message and mark as partial
        if let index = messages.firstIndex(where: { $0.status == .streaming }) {
            let savedContent = messages[index].content
            let chunkCount = messages[index].metadata.chunkCount
            
            messages[index].status = .partial(savedAt: Date(), lastChunk: chunkCount)
            messages[index].metadata.networkInterruptions += 1
            
            partialMessage = messages[index]
            hasPartialContent = true
            
            addSystemMessage("Network connection lost. \(savedContent.count) characters saved.")
        }
    }
    
    private func handlePartialStream(messageId: UUID, lastChunk: Int, content: String) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .partial(savedAt: Date(), lastChunk: lastChunk)
            messages[index].content = content
            partialMessage = messages[index]
            hasPartialContent = true
        }
    }
    
    private func handleStreamError(messageId: UUID, error: Error) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .failed(reason: error.localizedDescription)
        }
    }
    
    private func markMessageComplete(messageId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .complete
        }
    }
    
    func resumePartialStream() async {
        guard let partial = partialMessage else { return }
        
        // Update status
        if let index = messages.firstIndex(where: { $0.id == partial.id }) {
            messages[index].status = .resumed
            hasPartialContent = false
        }
        
        // Create continuation prompt
        let continuationPrompt = "Continue from: '\(partial.content.suffix(50))'"
        
        await streamWithResilience(prompt: continuationPrompt, resumeFrom: partial)
    }
    
    private func savePartialContent(messageId: UUID, content: String) {
        // In a real app, save to persistent storage
        print("Saving partial content: \(content.count) characters")
    }
    
    private func addSystemMessage(_ text: String) {
        let message = NetworkMessage(
            role: "system",
            content: text,
            status: .complete,
            metadata: NetworkMessage.StreamMetadata(
                startTime: Date(),
                lastUpdateTime: Date(),
                chunkCount: 1,
                bytesSaved: text.count,
                networkInterruptions: 0
            )
        )
        messages.append(message)
    }
}

// Network monitoring
class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    var pathUpdateHandler: ((NWPath) -> Void)?
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
            self?.pathUpdateHandler?(path)
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// Custom error for network streaming
enum NetworkStreamError: Error {
    case connectionLost(afterChunk: Int, partialContent: String)
}

// UI Components
struct NetworkStatusHeader: View {
    @ObservedObject var monitor: NetworkMonitor
    
    var body: some View {
        HStack {
            Image(systemName: monitor.isConnected ? "wifi" : "wifi.slash")
                .foregroundColor(monitor.isConnected ? .green : .red)
            
            Text(monitor.isConnected ? "Connected" : "Offline")
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .background(monitor.isConnected ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ConnectionQualityView: View {
    let quality: NetworkResilientStream.ConnectionQuality
    
    var body: some View {
        HStack {
            Text("Connection Quality:")
                .font(.caption)
            
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    Rectangle()
                        .fill(barColor(for: index))
                        .frame(width: 8, height: CGFloat(8 + index * 3))
                }
            }
            
            Text(qualityText)
                .font(.caption)
                .foregroundColor(textColor)
        }
    }
    
    func barColor(for index: Int) -> Color {
        let activeCount: Int
        switch quality {
        case .excellent: activeCount = 4
        case .good: activeCount = 3
        case .fair: activeCount = 2
        case .poor: activeCount = 1
        case .offline: activeCount = 0
        }
        
        return index < activeCount ? .green : .gray.opacity(0.3)
    }
    
    var qualityText: String {
        switch quality {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .offline: return "Offline"
        }
    }
    
    var textColor: Color {
        switch quality {
        case .excellent, .good: return .green
        case .fair: return .orange
        case .poor, .offline: return .red
        }
    }
}

struct NetworkAwareMessageView: View {
    let message: NetworkResilientStream.NetworkMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.role.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                MessageStatusIndicator(status: message.status)
            }
            
            Text(message.content)
                .padding()
                .background(backgroundForRole)
                .cornerRadius(10)
            
            MessageMetadataView(metadata: message.metadata, status: message.status)
        }
    }
    
    var backgroundForRole: Color {
        switch message.role {
        case "user": return Color.blue.opacity(0.1)
        case "assistant": return Color.gray.opacity(0.1)
        case "system": return Color.orange.opacity(0.1)
        default: return Color.gray.opacity(0.1)
        }
    }
}

struct MessageStatusIndicator: View {
    let status: NetworkResilientStream.NetworkMessage.MessageStatus
    
    var body: some View {
        switch status {
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .streaming:
            ProgressView()
                .scaleEffect(0.8)
        case .partial:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .resumed:
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(.blue)
        }
    }
}

struct MessageMetadataView: View {
    let metadata: NetworkResilientStream.NetworkMessage.StreamMetadata
    let status: NetworkResilientStream.NetworkMessage.MessageStatus
    
    var body: some View {
        HStack(spacing: 16) {
            Label("\(metadata.chunkCount) chunks", systemImage: "square.stack")
            
            if metadata.networkInterruptions > 0 {
                Label("\(metadata.networkInterruptions) interruptions", 
                      systemImage: "wifi.exclamationmark")
                    .foregroundColor(.orange)
            }
            
            if case .partial(let savedAt, _) = status {
                Label("Saved \(savedAt, style: .time)", systemImage: "square.and.arrow.down")
                    .foregroundColor(.blue)
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}

struct PartialContentRecoveryView: View {
    @ObservedObject var stream: NetworkResilientStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Partial response saved", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("The network was interrupted but we saved your partial response. You can resume when the connection is restored.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Resume Stream") {
                    Task {
                        await stream.resumePartialStream()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!stream.isNetworkAvailable)
                
                Button("Discard") {
                    stream.hasPartialContent = false
                    stream.partialMessage = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}