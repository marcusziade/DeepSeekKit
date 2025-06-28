import SwiftUI
import DeepSeekKit

// Implementing offline mode with queuing
struct OfflineModeView: View {
    @StateObject private var offlineManager = OfflineQueueManager()
    @State private var newPrompt = ""
    @State private var showSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Offline Mode & Queuing")
                    .font(.largeTitle)
                    .bold()
                
                // Connection status
                ConnectionStatusBanner(manager: offlineManager)
                
                // Offline queue overview
                QueueOverview(manager: offlineManager)
                
                // Queue items
                if !offlineManager.queue.isEmpty {
                    QueueItemsList(manager: offlineManager)
                }
                
                // Add to queue
                AddToQueueView(
                    manager: offlineManager,
                    prompt: $newPrompt
                )
                
                // Sync controls
                SyncControlsView(manager: offlineManager)
                
                // Storage info
                StorageInfoView(manager: offlineManager)
                
                // Settings
                if showSettings {
                    OfflineSettingsView(manager: offlineManager)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            }
        }
        .onAppear {
            offlineManager.startMonitoring()
        }
    }
}

// Offline queue manager
@MainActor
class OfflineQueueManager: ObservableObject {
    @Published var isOnline = true
    @Published var queue: [QueuedRequest] = []
    @Published var syncStatus: SyncStatus = .idle
    @Published var settings = OfflineSettings()
    @Published var storageUsed: Int64 = 0
    
    private let client = DeepSeekClient()
    private var syncTask: Task<Void, Never>?
    
    struct QueuedRequest: Identifiable, Codable {
        let id = UUID()
        let prompt: String
        let timestamp = Date()
        var priority: Priority = .normal
        var status: Status = .queued
        var retryCount = 0
        var response: String?
        var error: String?
        
        enum Priority: Int, Codable, CaseIterable {
            case low = 0
            case normal = 1
            case high = 2
            case urgent = 3
            
            var label: String {
                switch self {
                case .low: return "Low"
                case .normal: return "Normal"
                case .high: return "High"
                case .urgent: return "Urgent"
                }
            }
            
            var color: Color {
                switch self {
                case .low: return .gray
                case .normal: return .blue
                case .high: return .orange
                case .urgent: return .red
                }
            }
        }
        
        enum Status: String, Codable {
            case queued = "Queued"
            case sending = "Sending"
            case completed = "Completed"
            case failed = "Failed"
            case cancelled = "Cancelled"
            
            var icon: String {
                switch self {
                case .queued: return "clock"
                case .sending: return "arrow.up.circle"
                case .completed: return "checkmark.circle.fill"
                case .failed: return "exclamationmark.circle.fill"
                case .cancelled: return "xmark.circle.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .queued: return .gray
                case .sending: return .blue
                case .completed: return .green
                case .failed: return .red
                case .cancelled: return .orange
                }
            }
        }
    }
    
    enum SyncStatus {
        case idle
        case syncing(current: Int, total: Int)
        case completed
        case failed(error: String)
        
        var description: String {
            switch self {
            case .idle:
                return "Ready to sync"
            case .syncing(let current, let total):
                return "Syncing \(current) of \(total)"
            case .completed:
                return "Sync completed"
            case .failed(let error):
                return "Sync failed: \(error)"
            }
        }
    }
    
    struct OfflineSettings: Codable {
        var maxQueueSize = 100
        var autoSync = true
        var syncOnWiFiOnly = true
        var retryFailedRequests = true
        var maxRetries = 3
        var queueExpiration = 7 // days
        var compressStorage = true
    }
    
    init() {
        loadQueue()
        calculateStorageUsed()
    }
    
    func startMonitoring() {
        // Simulate connection monitoring
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            // In real app, use Network framework
            self.checkConnection()
        }
    }
    
    private func checkConnection() {
        // Simulate connection check
        let wasOnline = isOnline
        
        // Random connection status for demo
        if Bool.random() || queue.isEmpty {
            isOnline = true
        }
        
        // Auto-sync when connection restored
        if !wasOnline && isOnline && settings.autoSync && !queue.isEmpty {
            Task {
                await syncQueue()
            }
        }
    }
    
    func addToQueue(_ prompt: String, priority: QueuedRequest.Priority = .normal) {
        guard queue.count < settings.maxQueueSize else {
            // Queue full - remove oldest completed items
            cleanupQueue()
            guard queue.count < settings.maxQueueSize else { return }
        }
        
        let request = QueuedRequest(prompt: prompt, priority: priority)
        queue.append(request)
        sortQueue()
        saveQueue()
        calculateStorageUsed()
        
        // Try to send immediately if online
        if isOnline && settings.autoSync {
            Task {
                await syncQueue()
            }
        }
    }
    
    func syncQueue() async {
        guard isOnline else { return }
        guard syncTask == nil else { return } // Prevent multiple syncs
        
        let pendingRequests = queue.filter { 
            $0.status == .queued || 
            ($0.status == .failed && $0.retryCount < settings.maxRetries && settings.retryFailedRequests)
        }
        
        guard !pendingRequests.isEmpty else {
            syncStatus = .idle
            return
        }
        
        syncTask = Task {
            await performSync(requests: pendingRequests)
        }
        
        await syncTask?.value
        syncTask = nil
    }
    
    private func performSync(requests: [QueuedRequest]) async {
        for (index, request) in requests.enumerated() {
            guard !Task.isCancelled else { break }
            guard isOnline else {
                syncStatus = .failed(error: "Connection lost")
                break
            }
            
            syncStatus = .syncing(current: index + 1, total: requests.count)
            
            // Update request status
            if let queueIndex = queue.firstIndex(where: { $0.id == request.id }) {
                queue[queueIndex].status = .sending
            }
            
            // Send request
            do {
                let response = try await client.sendMessage(request.prompt)
                
                // Update with response
                if let queueIndex = queue.firstIndex(where: { $0.id == request.id }) {
                    queue[queueIndex].status = .completed
                    queue[queueIndex].response = response.choices.first?.message.content
                }
                
            } catch {
                // Handle failure
                if let queueIndex = queue.firstIndex(where: { $0.id == request.id }) {
                    queue[queueIndex].status = .failed
                    queue[queueIndex].error = error.localizedDescription
                    queue[queueIndex].retryCount += 1
                }
            }
            
            saveQueue()
            
            // Small delay between requests
            if index < requests.count - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }
        
        syncStatus = .completed
        cleanupQueue()
    }
    
    func retryRequest(_ id: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        
        queue[index].status = .queued
        queue[index].retryCount += 1
        queue[index].error = nil
        
        saveQueue()
        
        if isOnline {
            Task {
                await syncQueue()
            }
        }
    }
    
    func cancelRequest(_ id: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        
        queue[index].status = .cancelled
        saveQueue()
    }
    
    func deleteRequest(_ id: UUID) {
        queue.removeAll { $0.id == id }
        saveQueue()
        calculateStorageUsed()
    }
    
    func changePriority(_ id: UUID, to priority: QueuedRequest.Priority) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        
        queue[index].priority = priority
        sortQueue()
        saveQueue()
    }
    
    private func sortQueue() {
        queue.sort { first, second in
            // Sort by status first (pending before completed)
            if first.status == .queued && second.status != .queued {
                return true
            } else if first.status != .queued && second.status == .queued {
                return false
            }
            
            // Then by priority
            if first.priority.rawValue != second.priority.rawValue {
                return first.priority.rawValue > second.priority.rawValue
            }
            
            // Finally by timestamp
            return first.timestamp < second.timestamp
        }
    }
    
    private func cleanupQueue() {
        let expirationDate = Date().addingTimeInterval(-TimeInterval(settings.queueExpiration * 24 * 60 * 60))
        
        queue.removeAll { request in
            // Remove old completed requests
            if request.status == .completed && request.timestamp < expirationDate {
                return true
            }
            
            // Remove cancelled requests
            if request.status == .cancelled {
                return true
            }
            
            // Remove failed requests that exceeded retry limit
            if request.status == .failed && request.retryCount >= settings.maxRetries {
                return true
            }
            
            return false
        }
        
        saveQueue()
        calculateStorageUsed()
    }
    
    func clearQueue() {
        queue.removeAll()
        saveQueue()
        calculateStorageUsed()
    }
    
    func clearCompleted() {
        queue.removeAll { $0.status == .completed }
        saveQueue()
        calculateStorageUsed()
    }
    
    private func saveQueue() {
        // Save to persistent storage
        if let encoded = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(encoded, forKey: "offline_queue")
            
            if settings.compressStorage {
                // Compress data in real implementation
            }
        }
    }
    
    private func loadQueue() {
        if let data = UserDefaults.standard.data(forKey: "offline_queue"),
           let decoded = try? JSONDecoder().decode([QueuedRequest].self, from: data) {
            queue = decoded
            sortQueue()
        }
    }
    
    private func calculateStorageUsed() {
        if let data = try? JSONEncoder().encode(queue) {
            storageUsed = Int64(data.count)
        }
    }
}

// UI Components
struct ConnectionStatusBanner: View {
    @ObservedObject var manager: OfflineQueueManager
    
    var body: some View {
        HStack {
            Image(systemName: manager.isOnline ? "wifi" : "wifi.slash")
                .font(.title2)
                .foregroundColor(manager.isOnline ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(manager.isOnline ? "Online" : "Offline Mode")
                    .font(.headline)
                
                Text(manager.isOnline ? 
                     "Requests will be sent immediately" : 
                     "Requests will be queued and sent when online")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !manager.isOnline && !manager.queue.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(manager.queue.filter { $0.status == .queued }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Queued")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(manager.isOnline ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct QueueOverview: View {
    @ObservedObject var manager: OfflineQueueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Queue Overview")
                .font(.headline)
            
            // Queue statistics
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QueueStatCard(
                    title: "Total",
                    count: manager.queue.count,
                    color: .blue
                )
                
                QueueStatCard(
                    title: "Pending",
                    count: manager.queue.filter { $0.status == .queued }.count,
                    color: .orange
                )
                
                QueueStatCard(
                    title: "Completed",
                    count: manager.queue.filter { $0.status == .completed }.count,
                    color: .green
                )
            }
            
            // Sync status
            if case .syncing(let current, let total) = manager.syncStatus {
                VStack(spacing: 8) {
                    HStack {
                        Text("Syncing...")
                            .font(.subheadline)
                        Spacer()
                        Text("\(current) of \(total)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    
                    ProgressView(value: Double(current), total: Double(total))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct QueueStatCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct QueueItemsList: View {
    @ObservedObject var manager: OfflineQueueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Queue Items")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button("Clear All", role: .destructive) {
                        manager.clearQueue()
                    }
                    
                    Button("Clear Completed") {
                        manager.clearCompleted()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            ForEach(manager.queue) { request in
                QueueItemRow(
                    request: request,
                    manager: manager
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct QueueItemRow: View {
    let request: OfflineQueueManager.QueuedRequest
    @ObservedObject var manager: OfflineQueueManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack {
                Image(systemName: request.status.icon)
                    .foregroundColor(request.status.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.prompt)
                        .font(.subheadline)
                        .lineLimit(isExpanded ? nil : 1)
                    
                    HStack {
                        Text(request.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if request.retryCount > 0 {
                            Text("• Retry \(request.retryCount)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Priority badge
                PriorityBadge(priority: request.priority)
                
                // Expand button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let response = request.response {
                        Text("Response:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(response)
                            .font(.caption)
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    if let error = request.error {
                        Text("Error:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    // Actions
                    HStack(spacing: 12) {
                        if request.status == .failed && request.retryCount < manager.settings.maxRetries {
                            Button("Retry") {
                                manager.retryRequest(request.id)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        
                        if request.status == .queued || request.status == .failed {
                            Menu {
                                ForEach(OfflineQueueManager.QueuedRequest.Priority.allCases, id: \.self) { priority in
                                    Button(priority.label) {
                                        manager.changePriority(request.id, to: priority)
                                    }
                                }
                            } label: {
                                Label("Priority", systemImage: "flag")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if request.status != .sending {
                            Button("Delete", role: .destructive) {
                                manager.deleteRequest(request.id)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct PriorityBadge: View {
    let priority: OfflineQueueManager.QueuedRequest.Priority
    
    var body: some View {
        Text(priority.label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.color)
            .cornerRadius(6)
    }
}

struct AddToQueueView: View {
    @ObservedObject var manager: OfflineQueueManager
    @Binding var prompt: String
    @State private var selectedPriority: OfflineQueueManager.QueuedRequest.Priority = .normal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Queue")
                .font(.headline)
            
            TextField("Enter your prompt", text: $prompt)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Picker("Priority", selection: $selectedPriority) {
                    ForEach(OfflineQueueManager.QueuedRequest.Priority.allCases, id: \.self) { priority in
                        Text(priority.label).tag(priority)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Button("Add") {
                    manager.addToQueue(prompt, priority: selectedPriority)
                    prompt = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.isEmpty)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct SyncControlsView: View {
    @ObservedObject var manager: OfflineQueueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Controls")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.syncStatus.description)
                        .font(.subheadline)
                    
                    if manager.settings.autoSync {
                        Label("Auto-sync enabled", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Button("Sync Now") {
                    Task {
                        await manager.syncQueue()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!manager.isOnline || manager.syncTask != nil)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct StorageInfoView: View {
    @ObservedObject var manager: OfflineQueueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Storage Used", systemImage: "internaldrive")
                    .font(.caption)
                
                Spacer()
                
                Text(formatBytes(manager.storageUsed))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: Double(manager.queue.count), total: Double(manager.settings.maxQueueSize))
                .tint(storageColor)
            
            HStack {
                Text("\(manager.queue.count) of \(manager.settings.maxQueueSize) items")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if manager.settings.compressStorage {
                    Label("Compressed", systemImage: "rectangle.compress.vertical")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    var storageColor: Color {
        let usage = Double(manager.queue.count) / Double(manager.settings.maxQueueSize)
        if usage < 0.5 {
            return .green
        } else if usage < 0.8 {
            return .orange
        } else {
            return .red
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

struct OfflineSettingsView: View {
    @ObservedObject var manager: OfflineQueueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Offline Settings")
                .font(.headline)
            
            Toggle("Auto-sync when online", isOn: $manager.settings.autoSync)
            
            Toggle("Sync on Wi-Fi only", isOn: $manager.settings.syncOnWiFiOnly)
            
            Toggle("Retry failed requests", isOn: $manager.settings.retryFailedRequests)
            
            HStack {
                Text("Max retries:")
                Stepper("\(manager.settings.maxRetries)", value: $manager.settings.maxRetries, in: 1...5)
            }
            
            HStack {
                Text("Queue expiration:")
                Stepper("\(manager.settings.queueExpiration) days", value: $manager.settings.queueExpiration, in: 1...30)
            }
            
            Toggle("Compress storage", isOn: $manager.settings.compressStorage)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}