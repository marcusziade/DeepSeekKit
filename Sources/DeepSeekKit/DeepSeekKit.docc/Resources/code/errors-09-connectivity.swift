import SwiftUI
import DeepSeekKit
import Network

// Detecting network connectivity status
struct NetworkConnectivityView: View {
    @StateObject private var connectivityManager = ConnectivityManager()
    @State private var testMessage = "Test network resilience"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Network Connectivity")
                    .font(.largeTitle)
                    .bold()
                
                // Connection status card
                ConnectionStatusCard(manager: connectivityManager)
                
                // Network details
                NetworkDetailsView(manager: connectivityManager)
                
                // Connection quality meter
                ConnectionQualityMeter(manager: connectivityManager)
                
                // Offline mode handler
                OfflineModeView(manager: connectivityManager)
                
                // Network test controls
                NetworkTestControls(
                    manager: connectivityManager,
                    testMessage: $testMessage
                )
                
                // Connection history
                ConnectionHistoryView(history: connectivityManager.connectionHistory)
            }
            .padding()
        }
        .onAppear {
            connectivityManager.startMonitoring()
        }
        .onDisappear {
            connectivityManager.stopMonitoring()
        }
    }
}

// Connectivity manager
@MainActor
class ConnectivityManager: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var connectionQuality: ConnectionQuality = .unknown
    @Published var isExpensive = false
    @Published var isConstrained = false
    @Published var connectionHistory: [ConnectionEvent] = []
    @Published var offlineQueue: [OfflineRequest] = []
    @Published var networkStats = NetworkStats()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let client = DeepSeekClient()
    private var pingTimer: Timer?
    
    enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"
        
        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .unknown: return "questionmark.circle"
            }
        }
    }
    
    enum ConnectionQuality: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case offline = "Offline"
        case unknown = "Unknown"
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            case .offline: return .gray
            case .unknown: return .gray
            }
        }
        
        var speedRange: String {
            switch self {
            case .excellent: return "> 50 Mbps"
            case .good: return "10-50 Mbps"
            case .fair: return "1-10 Mbps"
            case .poor: return "< 1 Mbps"
            case .offline: return "0 Mbps"
            case .unknown: return "Testing..."
            }
        }
    }
    
    struct ConnectionEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: EventType
        let previousState: ConnectionType
        let newState: ConnectionType
        let quality: ConnectionQuality
        
        enum EventType {
            case connected
            case disconnected
            case typeChanged
            case qualityChanged
        }
    }
    
    struct OfflineRequest: Identifiable {
        let id = UUID()
        let prompt: String
        let timestamp: Date
        var status: Status = .pending
        
        enum Status {
            case pending
            case syncing
            case completed
            case failed
        }
    }
    
    struct NetworkStats {
        var totalRequests = 0
        var successfulRequests = 0
        var failedRequests = 0
        var offlineRequests = 0
        var averageLatency: TimeInterval = 0
        var dataUsage: Int64 = 0 // bytes
        
        var successRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(successfulRequests) / Double(totalRequests)
        }
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path: path)
            }
        }
        monitor.start(queue: queue)
        
        // Start quality monitoring
        startQualityMonitoring()
    }
    
    func stopMonitoring() {
        monitor.cancel()
        pingTimer?.invalidate()
    }
    
    private func updateConnectionStatus(path: NWPath) {
        let wasConnected = isConnected
        let previousType = connectionType
        
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
        
        // Log connection event
        if wasConnected != isConnected {
            let event = ConnectionEvent(
                timestamp: Date(),
                type: isConnected ? .connected : .disconnected,
                previousState: previousType,
                newState: connectionType,
                quality: connectionQuality
            )
            connectionHistory.insert(event, at: 0)
            
            // Handle offline queue when reconnected
            if isConnected && !offlineQueue.isEmpty {
                Task {
                    await syncOfflineQueue()
                }
            }
        } else if previousType != connectionType {
            let event = ConnectionEvent(
                timestamp: Date(),
                type: .typeChanged,
                previousState: previousType,
                newState: connectionType,
                quality: connectionQuality
            )
            connectionHistory.insert(event, at: 0)
        }
        
        // Update quality based on connection type
        updateConnectionQuality()
    }
    
    private func startQualityMonitoring() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                await self.measureConnectionQuality()
            }
        }
    }
    
    private func measureConnectionQuality() async {
        guard isConnected else {
            connectionQuality = .offline
            return
        }
        
        let startTime = Date()
        
        do {
            // Simple latency test
            _ = try await client.sendMessage("ping", maxTokens: 1)
            
            let latency = Date().timeIntervalSince(startTime)
            networkStats.averageLatency = latency
            
            // Determine quality based on latency and connection type
            if latency < 0.5 {
                connectionQuality = .excellent
            } else if latency < 1.0 {
                connectionQuality = .good
            } else if latency < 2.0 {
                connectionQuality = .fair
            } else {
                connectionQuality = .poor
            }
            
            // Adjust for connection type
            if isExpensive || isConstrained {
                connectionQuality = min(connectionQuality, .fair)
            }
            
        } catch {
            // Network error during quality check
            if isConnected {
                connectionQuality = .poor
            } else {
                connectionQuality = .offline
            }
        }
    }
    
    private func updateConnectionQuality() {
        if !isConnected {
            connectionQuality = .offline
        } else if isConstrained {
            connectionQuality = .poor
        } else if isExpensive {
            connectionQuality = .fair
        } else {
            // Will be updated by quality monitoring
            connectionQuality = .unknown
        }
    }
    
    func sendRequest(_ prompt: String) async -> Result<String, Error> {
        networkStats.totalRequests += 1
        
        guard isConnected else {
            // Add to offline queue
            let request = OfflineRequest(prompt: prompt, timestamp: Date())
            offlineQueue.append(request)
            networkStats.offlineRequests += 1
            
            return .failure(DeepSeekError.networkError(URLError(.notConnectedToInternet)))
        }
        
        do {
            let response = try await client.sendMessage(prompt)
            networkStats.successfulRequests += 1
            
            // Estimate data usage
            let requestSize = prompt.data(using: .utf8)?.count ?? 0
            let responseSize = response.choices.first?.message.content.data(using: .utf8)?.count ?? 0
            networkStats.dataUsage += Int64(requestSize + responseSize)
            
            return .success(response.choices.first?.message.content ?? "")
        } catch {
            networkStats.failedRequests += 1
            return .failure(error)
        }
    }
    
    private func syncOfflineQueue() async {
        let pendingRequests = offlineQueue.filter { $0.status == .pending }
        
        for (index, request) in pendingRequests.enumerated() {
            guard isConnected else { break }
            
            // Update status
            if let queueIndex = offlineQueue.firstIndex(where: { $0.id == request.id }) {
                offlineQueue[queueIndex].status = .syncing
            }
            
            // Attempt to send
            let result = await sendRequest(request.prompt)
            
            // Update based on result
            if let queueIndex = offlineQueue.firstIndex(where: { $0.id == request.id }) {
                switch result {
                case .success:
                    offlineQueue[queueIndex].status = .completed
                case .failure:
                    offlineQueue[queueIndex].status = .failed
                }
            }
            
            // Small delay between requests
            if index < pendingRequests.count - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }
        
        // Clean up completed requests
        offlineQueue.removeAll { $0.status == .completed }
    }
    
    func clearOfflineQueue() {
        offlineQueue.removeAll()
    }
    
    func retryFailedRequests() {
        for index in offlineQueue.indices {
            if offlineQueue[index].status == .failed {
                offlineQueue[index].status = .pending
            }
        }
        
        if isConnected {
            Task {
                await syncOfflineQueue()
            }
        }
    }
}

// UI Components
struct ConnectionStatusCard: View {
    @ObservedObject var manager: ConnectivityManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                // Connection icon
                ZStack {
                    Circle()
                        .fill(manager.isConnected ? Color.green : Color.red)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: manager.connectionType.icon)
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(manager.isConnected ? "Connected" : "Offline")
                        .font(.title2)
                        .bold()
                    
                    HStack {
                        Text(manager.connectionType.rawValue)
                            .font(.subheadline)
                        
                        if manager.isExpensive {
                            Label("Metered", systemImage: "dollarsign.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if manager.isConstrained {
                            Label("Limited", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Connection quality bar
            ConnectionQualityBar(quality: manager.connectionQuality)
        }
        .padding()
        .background(manager.isConnected ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ConnectionQualityBar: View {
    let quality: ConnectivityManager.ConnectionQuality
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quality: \(quality.rawValue)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(quality.speedRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(quality.color)
                        .frame(width: qualityWidth(in: geometry.size.width), height: 8)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
        }
    }
    
    func qualityWidth(in totalWidth: CGFloat) -> CGFloat {
        switch quality {
        case .excellent: return totalWidth
        case .good: return totalWidth * 0.75
        case .fair: return totalWidth * 0.5
        case .poor: return totalWidth * 0.25
        case .offline, .unknown: return 0
        }
    }
}

struct NetworkDetailsView: View {
    @ObservedObject var manager: ConnectivityManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Details")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DetailCard(
                    title: "Latency",
                    value: String(format: "%.0f ms", manager.networkStats.averageLatency * 1000),
                    icon: "speedometer",
                    color: .blue
                )
                
                DetailCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", manager.networkStats.successRate * 100),
                    icon: "checkmark.circle",
                    color: .green
                )
                
                DetailCard(
                    title: "Data Used",
                    value: formatDataUsage(manager.networkStats.dataUsage),
                    icon: "arrow.up.arrow.down",
                    color: .orange
                )
                
                DetailCard(
                    title: "Offline Queue",
                    value: "\(manager.offlineQueue.count)",
                    icon: "tray.full",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    func formatDataUsage(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

struct DetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ConnectionQualityMeter: View {
    @ObservedObject var manager: ConnectivityManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Quality Meter")
                .font(.headline)
            
            // Visual meter
            GeometryReader { geometry in
                ZStack {
                    // Background arc
                    Path { path in
                        path.addArc(
                            center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height),
                            radius: geometry.size.width / 2 - 20,
                            startAngle: .degrees(180),
                            endAngle: .degrees(0),
                            clockwise: false
                        )
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    
                    // Quality arc
                    Path { path in
                        path.addArc(
                            center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height),
                            radius: geometry.size.width / 2 - 20,
                            startAngle: .degrees(180),
                            endAngle: .degrees(180 - qualityAngle),
                            clockwise: false
                        )
                    }
                    .stroke(manager.connectionQuality.color, lineWidth: 20)
                    
                    // Needle
                    Path { path in
                        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height)
                        let angle = Angle(degrees: 180 - qualityAngle)
                        let needleLength = geometry.size.width / 2 - 30
                        
                        path.move(to: center)
                        path.addLine(to: CGPoint(
                            x: center.x + cos(angle.radians) * needleLength,
                            y: center.y - sin(angle.radians) * needleLength
                        ))
                    }
                    .stroke(Color.black, lineWidth: 3)
                    
                    // Center dot
                    Circle()
                        .fill(Color.black)
                        .frame(width: 10, height: 10)
                        .position(x: geometry.size.width / 2, y: geometry.size.height)
                    
                    // Quality text
                    Text(manager.connectionQuality.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .position(x: geometry.size.width / 2, y: geometry.size.height - 40)
                }
            }
            .frame(height: 120)
            
            // Legend
            HStack {
                ForEach([
                    ConnectivityManager.ConnectionQuality.poor,
                    .fair,
                    .good,
                    .excellent
                ], id: \.self) { quality in
                    HStack {
                        Circle()
                            .fill(quality.color)
                            .frame(width: 8, height: 8)
                        Text(quality.rawValue)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    var qualityAngle: Double {
        switch manager.connectionQuality {
        case .excellent: return 180
        case .good: return 135
        case .fair: return 90
        case .poor: return 45
        case .offline, .unknown: return 0
        }
    }
}

struct OfflineModeView: View {
    @ObservedObject var manager: ConnectivityManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Offline Mode", systemImage: "icloud.slash")
                    .font(.headline)
                
                Spacer()
                
                if !manager.offlineQueue.isEmpty {
                    Button("Clear Queue") {
                        manager.clearOfflineQueue()
                    }
                    .font(.caption)
                }
            }
            
            if manager.offlineQueue.isEmpty {
                Text("No offline requests queued")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(manager.offlineQueue) { request in
                        OfflineRequestRow(request: request)
                    }
                }
                
                if manager.isConnected {
                    Button("Retry Failed Requests") {
                        manager.retryFailedRequests()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct OfflineRequestRow: View {
    let request: ConnectivityManager.OfflineRequest
    
    var body: some View {
        HStack {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.prompt)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(request.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 4)
    }
    
    var statusIcon: some View {
        Group {
            switch request.status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundColor(.gray)
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .frame(width: 20)
    }
    
    var statusText: String {
        switch request.status {
        case .pending: return "Queued"
        case .syncing: return "Syncing"
        case .completed: return "Sent"
        case .failed: return "Failed"
        }
    }
    
    var statusColor: Color {
        switch request.status {
        case .pending: return .gray
        case .syncing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct NetworkTestControls: View {
    @ObservedObject var manager: ConnectivityManager
    @Binding var testMessage: String
    @State private var testResult: String?
    @State private var isTesting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Test")
                .font(.headline)
            
            TextField("Test message", text: $testMessage)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Test Connection") {
                    Task {
                        await testConnection()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting)
                
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .padding()
                    .background(result.contains("Success") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
    
    func testConnection() async {
        isTesting = true
        testResult = nil
        
        let result = await manager.sendRequest(testMessage)
        
        switch result {
        case .success(let response):
            testResult = "Success! Response: \(response.prefix(100))..."
        case .failure(let error):
            testResult = "Failed: \(error.localizedDescription)"
        }
        
        isTesting = false
    }
}

struct ConnectionHistoryView: View {
    let history: [ConnectivityManager.ConnectionEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection History")
                .font(.headline)
            
            if history.isEmpty {
                Text("No connection events")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(history.prefix(10)) { event in
                    ConnectionEventRow(event: event)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ConnectionEventRow: View {
    let event: ConnectivityManager.ConnectionEvent
    
    var body: some View {
        HStack {
            eventIcon
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(eventDescription)
                    .font(.caption)
                
                Text(event.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(event.quality.rawValue)
                .font(.caption2)
                .foregroundColor(event.quality.color)
        }
        .padding(.vertical, 4)
    }
    
    var eventIcon: some View {
        Group {
            switch event.type {
            case .connected:
                Image(systemName: "wifi")
                    .foregroundColor(.green)
            case .disconnected:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.red)
            case .typeChanged:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
            case .qualityChanged:
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
            }
        }
        .font(.caption)
    }
    
    var eventDescription: String {
        switch event.type {
        case .connected:
            return "Connected via \(event.newState.rawValue)"
        case .disconnected:
            return "Disconnected from \(event.previousState.rawValue)"
        case .typeChanged:
            return "Switched from \(event.previousState.rawValue) to \(event.newState.rawValue)"
        case .qualityChanged:
            return "Quality changed to \(event.quality.rawValue)"
        }
    }
}