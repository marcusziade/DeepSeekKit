import SwiftUI
import DeepSeekKit

// Streaming multiple responses simultaneously
struct MultiStreamView: View {
    @StateObject private var multiStream = MultiStreamManager()
    @State private var prompt = ""
    @State private var selectedConfigurations: Set<StreamConfiguration.ID> = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Multi-Stream Comparison")
                .font(.largeTitle)
                .bold()
            
            // Configuration selector
            ConfigurationSelector(
                configurations: multiStream.availableConfigurations,
                selected: $selectedConfigurations
            )
            
            // Stream grid
            ScrollView {
                if multiStream.activeStreams.isEmpty {
                    EmptyStreamView()
                } else {
                    StreamComparisonGrid(streams: multiStream.activeStreams)
                }
            }
            
            // Performance metrics
            if multiStream.isAnyStreaming {
                PerformanceMetricsView(manager: multiStream)
            }
            
            // Input and controls
            VStack(spacing: 12) {
                HStack {
                    TextField("Enter prompt for all streams", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Stream All") {
                        Task {
                            await multiStream.startMultipleStreams(
                                prompt: prompt,
                                configurations: Array(selectedConfigurations)
                            )
                        }
                    }
                    .disabled(prompt.isEmpty || selectedConfigurations.isEmpty || multiStream.isAnyStreaming)
                    .buttonStyle(.borderedProminent)
                }
                
                // Quick actions
                HStack {
                    Button("Compare Models") {
                        selectedConfigurations = Set(multiStream.modelComparisonConfigs.map { $0.id })
                    }
                    
                    Button("Compare Temperatures") {
                        selectedConfigurations = Set(multiStream.temperatureComparisonConfigs.map { $0.id })
                    }
                    
                    Button("Compare Prompts") {
                        selectedConfigurations = Set(multiStream.promptVariationConfigs.map { $0.id })
                    }
                    
                    Spacer()
                    
                    if multiStream.isAnyStreaming {
                        Button("Stop All") {
                            multiStream.cancelAllStreams()
                        }
                        .foregroundColor(.red)
                    }
                }
                .font(.caption)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Multi-stream manager
@MainActor
class MultiStreamManager: ObservableObject {
    @Published var activeStreams: [StreamInstance] = []
    @Published var isAnyStreaming: Bool = false
    @Published var performanceMetrics = PerformanceMetrics()
    
    private var streamTasks: [UUID: Task<Void, Never>] = [:]
    private let maxConcurrentStreams = 4
    
    struct StreamConfiguration: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let model: DeepSeekModel
        let temperature: Double
        let systemPrompt: String?
        let color: Color
        
        static func == (lhs: StreamConfiguration, rhs: StreamConfiguration) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    struct StreamInstance: Identifiable {
        let id = UUID()
        let configuration: StreamConfiguration
        var content: String = ""
        var status: StreamStatus = .pending
        var metrics: StreamMetrics
        let startTime = Date()
        
        enum StreamStatus {
            case pending
            case streaming
            case complete
            case failed(error: String)
            case cancelled
        }
        
        struct StreamMetrics {
            var firstChunkTime: TimeInterval?
            var totalChunks: Int = 0
            var totalTokens: Int = 0
            var chunkRate: Double = 0 // chunks per second
            var characterCount: Int = 0
        }
    }
    
    struct PerformanceMetrics {
        var totalStreamsStarted: Int = 0
        var averageTimeToFirstChunk: TimeInterval = 0
        var averageCompletionTime: TimeInterval = 0
        var successRate: Double = 0
        var concurrentStreams: Int = 0
    }
    
    // Predefined configurations
    var availableConfigurations: [StreamConfiguration] {
        [
            StreamConfiguration(
                name: "DeepSeek Chat",
                model: .deepseekChat,
                temperature: 0.7,
                systemPrompt: nil,
                color: .blue
            ),
            StreamConfiguration(
                name: "DeepSeek Coder",
                model: .deepseekCoder,
                temperature: 0.3,
                systemPrompt: "You are a helpful coding assistant.",
                color: .green
            ),
            StreamConfiguration(
                name: "Creative Mode",
                model: .deepseekChat,
                temperature: 1.2,
                systemPrompt: "Be creative and imaginative.",
                color: .purple
            ),
            StreamConfiguration(
                name: "Precise Mode",
                model: .deepseekChat,
                temperature: 0.1,
                systemPrompt: "Be precise and factual.",
                color: .orange
            )
        ]
    }
    
    var modelComparisonConfigs: [StreamConfiguration] {
        [
            StreamConfiguration(
                name: "Chat Model",
                model: .deepseekChat,
                temperature: 0.7,
                systemPrompt: nil,
                color: .blue
            ),
            StreamConfiguration(
                name: "Coder Model",
                model: .deepseekCoder,
                temperature: 0.7,
                systemPrompt: nil,
                color: .green
            )
        ]
    }
    
    var temperatureComparisonConfigs: [StreamConfiguration] {
        [0.1, 0.5, 0.9, 1.3].enumerated().map { index, temp in
            StreamConfiguration(
                name: "Temp \(temp)",
                model: .deepseekChat,
                temperature: temp,
                systemPrompt: nil,
                color: [.blue, .green, .orange, .red][index]
            )
        }
    }
    
    var promptVariationConfigs: [StreamConfiguration] {
        [
            ("Technical", "Explain technically and precisely."),
            ("Simple", "Explain in simple terms."),
            ("Creative", "Be creative and use metaphors."),
            ("Concise", "Be very brief and concise.")
        ].enumerated().map { index, (name, system) in
            StreamConfiguration(
                name: name,
                model: .deepseekChat,
                temperature: 0.7,
                systemPrompt: system,
                color: [.blue, .green, .purple, .orange][index]
            )
        }
    }
    
    func startMultipleStreams(prompt: String, configurations: [UUID]) async {
        // Limit concurrent streams
        let selectedConfigs = availableConfigurations
            .filter { configurations.contains($0.id) }
            .prefix(maxConcurrentStreams)
        
        // Clear previous streams
        cancelAllStreams()
        activeStreams.removeAll()
        
        // Create stream instances
        for config in selectedConfigs {
            let instance = StreamInstance(
                configuration: config,
                metrics: StreamInstance.StreamMetrics()
            )
            activeStreams.append(instance)
        }
        
        isAnyStreaming = true
        performanceMetrics.totalStreamsStarted += activeStreams.count
        performanceMetrics.concurrentStreams = activeStreams.count
        
        // Start streams concurrently
        await withTaskGroup(of: Void.self) { group in
            for instance in activeStreams {
                group.addTask { [weak self] in
                    await self?.performStream(
                        instanceId: instance.id,
                        prompt: prompt
                    )
                }
            }
        }
        
        updatePerformanceMetrics()
        isAnyStreaming = false
    }
    
    private func performStream(instanceId: UUID, prompt: String) async {
        guard let index = activeStreams.firstIndex(where: { $0.id == instanceId }) else { return }
        
        let config = activeStreams[index].configuration
        let client = DeepSeekClient()
        
        // Update status
        activeStreams[index].status = .streaming
        
        let streamStartTime = Date()
        var firstChunkReceived = false
        var chunkCount = 0
        
        // Build messages
        var messages: [ChatMessage] = []
        if let systemPrompt = config.systemPrompt {
            messages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        messages.append(ChatMessage(role: "user", content: prompt))
        
        do {
            let request = ChatCompletionRequest(
                model: config.model,
                messages: messages,
                temperature: config.temperature,
                stream: true
            )
            
            for try await chunk in client.streamChatCompletion(request) {
                if Task.isCancelled { break }
                
                chunkCount += 1
                
                // Record first chunk time
                if !firstChunkReceived {
                    firstChunkReceived = true
                    let firstChunkTime = Date().timeIntervalSince(streamStartTime)
                    activeStreams[index].metrics.firstChunkTime = firstChunkTime
                }
                
                // Process content
                if let content = chunk.choices.first?.delta.content {
                    activeStreams[index].content += content
                    activeStreams[index].metrics.characterCount = activeStreams[index].content.count
                }
                
                // Update metrics
                if let usage = chunk.usage {
                    activeStreams[index].metrics.totalTokens = usage.totalTokens
                }
                
                activeStreams[index].metrics.totalChunks = chunkCount
                
                // Calculate chunk rate
                let elapsed = Date().timeIntervalSince(streamStartTime)
                if elapsed > 0 {
                    activeStreams[index].metrics.chunkRate = Double(chunkCount) / elapsed
                }
            }
            
            // Mark complete
            activeStreams[index].status = .complete
            
        } catch {
            activeStreams[index].status = .failed(error: error.localizedDescription)
        }
    }
    
    func cancelAllStreams() {
        for task in streamTasks.values {
            task.cancel()
        }
        streamTasks.removeAll()
        
        // Update statuses
        for index in activeStreams.indices {
            if case .streaming = activeStreams[index].status {
                activeStreams[index].status = .cancelled
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        let completedStreams = activeStreams.filter { 
            if case .complete = $0.status { return true }
            return false
        }
        
        if !completedStreams.isEmpty {
            // Average time to first chunk
            let firstChunkTimes = completedStreams.compactMap { $0.metrics.firstChunkTime }
            if !firstChunkTimes.isEmpty {
                performanceMetrics.averageTimeToFirstChunk = firstChunkTimes.reduce(0, +) / Double(firstChunkTimes.count)
            }
            
            // Success rate
            let successCount = completedStreams.count
            let totalCount = activeStreams.count
            performanceMetrics.successRate = totalCount > 0 ? Double(successCount) / Double(totalCount) : 0
        }
    }
}

// UI Components
struct ConfigurationSelector: View {
    let configurations: [MultiStreamManager.StreamConfiguration]
    @Binding var selected: Set<MultiStreamManager.StreamConfiguration.ID>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Streams to Compare")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(configurations) { config in
                        ConfigurationChip(
                            configuration: config,
                            isSelected: selected.contains(config.id),
                            action: {
                                if selected.contains(config.id) {
                                    selected.remove(config.id)
                                } else if selected.count < 4 {
                                    selected.insert(config.id)
                                }
                            }
                        )
                    }
                }
            }
            
            Text("\(selected.count) of 4 streams selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ConfigurationChip: View {
    let configuration: MultiStreamManager.StreamConfiguration
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                Text(configuration.name)
                    .font(.caption)
                Text("T: \(String(format: "%.1f", configuration.temperature))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? configuration.color : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
}

struct StreamComparisonGrid: View {
    let streams: [MultiStreamManager.StreamInstance]
    
    var body: some View {
        LazyVGrid(columns: adaptiveColumns, spacing: 16) {
            ForEach(streams) { stream in
                StreamCard(stream: stream)
            }
        }
        .padding()
    }
    
    var adaptiveColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: min(streams.count, 2))
    }
}

struct StreamCard: View {
    let stream: MultiStreamManager.StreamInstance
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.configuration.name)
                        .font(.headline)
                    Text(stream.configuration.model.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StreamStatusIndicator(status: stream.status)
            }
            
            // Content
            ScrollView {
                Text(stream.content.isEmpty ? "Waiting for response..." : stream.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: isExpanded ? 300 : 150)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            // Metrics
            StreamMetricsView(metrics: stream.metrics)
            
            // Expand/Collapse button
            Button(action: { isExpanded.toggle() }) {
                Label(isExpanded ? "Show Less" : "Show More", 
                      systemImage: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(stream.configuration.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(stream.configuration.color, lineWidth: 2)
        )
        .cornerRadius(12)
    }
}

struct StreamStatusIndicator: View {
    let status: MultiStreamManager.StreamInstance.StreamStatus
    
    var body: some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundColor(.gray)
            case .streaming:
                ProgressView()
                    .scaleEffect(0.8)
            case .complete:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

struct StreamMetricsView: View {
    let metrics: MultiStreamManager.StreamInstance.StreamMetrics
    
    var body: some View {
        HStack(spacing: 16) {
            if let firstChunk = metrics.firstChunkTime {
                MetricBadge(
                    label: "First chunk",
                    value: String(format: "%.2fs", firstChunk),
                    icon: "timer"
                )
            }
            
            MetricBadge(
                label: "Chunks",
                value: "\(metrics.totalChunks)",
                icon: "square.stack"
            )
            
            if metrics.chunkRate > 0 {
                MetricBadge(
                    label: "Rate",
                    value: String(format: "%.1f/s", metrics.chunkRate),
                    icon: "speedometer"
                )
            }
            
            if metrics.totalTokens > 0 {
                MetricBadge(
                    label: "Tokens",
                    value: "\(metrics.totalTokens)",
                    icon: "number"
                )
            }
        }
        .font(.caption2)
    }
}

struct MetricBadge: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .fontWeight(.medium)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct PerformanceMetricsView: View {
    @ObservedObject var manager: MultiStreamManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
            
            HStack(spacing: 20) {
                PerformanceMetric(
                    label: "Concurrent",
                    value: "\(manager.performanceMetrics.concurrentStreams)",
                    color: .blue
                )
                
                PerformanceMetric(
                    label: "Avg First Chunk",
                    value: String(format: "%.2fs", manager.performanceMetrics.averageTimeToFirstChunk),
                    color: .green
                )
                
                PerformanceMetric(
                    label: "Success Rate",
                    value: String(format: "%.0f%%", manager.performanceMetrics.successRate * 100),
                    color: .orange
                )
            }
            
            // Visual comparison
            StreamComparisonChart(streams: manager.activeStreams)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PerformanceMetric: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StreamComparisonChart: View {
    let streams: [MultiStreamManager.StreamInstance]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response Progress")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(streams) { stream in
                HStack {
                    Circle()
                        .fill(stream.configuration.color)
                        .frame(width: 8, height: 8)
                    
                    Text(stream.configuration.name)
                        .font(.caption2)
                        .frame(width: 80, alignment: .leading)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(stream.configuration.color)
                                .frame(width: progressWidth(for: stream, in: geometry.size.width), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(stream.metrics.characterCount)")
                        .font(.caption2)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
    
    func progressWidth(for stream: MultiStreamManager.StreamInstance, in totalWidth: CGFloat) -> CGFloat {
        let maxChars = streams.map { $0.metrics.characterCount }.max() ?? 1
        let progress = CGFloat(stream.metrics.characterCount) / CGFloat(maxChars)
        return totalWidth * progress
    }
}

struct EmptyStreamView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Active Streams")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Select configurations above and enter a prompt to start comparing multiple streams")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(50)
    }
}