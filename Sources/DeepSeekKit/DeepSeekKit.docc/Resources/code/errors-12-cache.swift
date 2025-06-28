import SwiftUI
import DeepSeekKit

// Adding request caching for resilience
struct RequestCachingView: View {
    @StateObject private var cacheManager = ResponseCacheManager()
    @State private var testPrompt = "What is SwiftUI?"
    @State private var showCacheDetails = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Request Caching")
                    .font(.largeTitle)
                    .bold()
                
                // Cache overview
                CacheOverviewCard(manager: cacheManager)
                
                // Cache hit rate visualization
                CacheHitRateView(manager: cacheManager)
                
                // Test controls
                CacheTestControls(
                    manager: cacheManager,
                    testPrompt: $testPrompt
                )
                
                // Cached items
                if showCacheDetails {
                    CachedItemsList(manager: cacheManager)
                }
                
                // Cache policies
                CachePoliciesView(manager: cacheManager)
                
                // Cache management
                CacheManagementView(manager: cacheManager)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(showCacheDetails ? "Hide Details" : "Show Details") {
                    showCacheDetails.toggle()
                }
            }
        }
    }
}

// Response cache manager
@MainActor
class ResponseCacheManager: ObservableObject {
    @Published var cache: [CacheEntry] = []
    @Published var stats = CacheStatistics()
    @Published var policy = CachePolicy()
    @Published var isLoading = false
    
    private let client = DeepSeekClient()
    private let maxCacheSize: Int64 = 50 * 1024 * 1024 // 50MB
    
    struct CacheEntry: Identifiable, Codable {
        let id = UUID()
        let key: String
        let prompt: String
        let response: String
        let timestamp = Date()
        var accessCount = 0
        var lastAccessed = Date()
        let size: Int
        let metadata: CacheMetadata
        
        struct CacheMetadata: Codable {
            let model: String
            let temperature: Double
            let maxTokens: Int?
            let responseTime: TimeInterval
        }
        
        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
        
        var isExpired: Bool {
            age > 86400 // 24 hours
        }
    }
    
    struct CacheStatistics {
        var totalRequests = 0
        var cacheHits = 0
        var cacheMisses = 0
        var totalSaved: TimeInterval = 0
        var currentSize: Int64 = 0
        
        var hitRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(cacheHits) / Double(totalRequests)
        }
        
        var averageTimeSaved: TimeInterval {
            guard cacheHits > 0 else { return 0 }
            return totalSaved / Double(cacheHits)
        }
    }
    
    struct CachePolicy: Codable {
        var enabled = true
        var maxAge: TimeInterval = 86400 // 24 hours
        var maxSize: Int64 = 50 * 1024 * 1024 // 50MB
        var evictionPolicy: EvictionPolicy = .lru
        var cacheableModels = Set<String>(["deepseek-chat", "deepseek-coder"])
        var minPromptLength = 10
        var excludePatterns: [String] = ["random", "current time", "today"]
        
        enum EvictionPolicy: String, CaseIterable, Codable {
            case lru = "Least Recently Used"
            case lfu = "Least Frequently Used"
            case fifo = "First In First Out"
            case ttl = "Time To Live"
        }
    }
    
    init() {
        loadCache()
    }
    
    func sendRequest(_ prompt: String, useCache: Bool = true) async -> RequestResult {
        stats.totalRequests += 1
        
        // Check if request is cacheable
        if useCache && policy.enabled && isCacheable(prompt) {
            // Generate cache key
            let key = generateCacheKey(prompt: prompt)
            
            // Check cache
            if let cached = getCachedResponse(key: key) {
                stats.cacheHits += 1
                stats.totalSaved += cached.metadata.responseTime
                
                return RequestResult(
                    response: cached.response,
                    fromCache: true,
                    responseTime: 0,
                    cacheKey: key
                )
            }
        }
        
        // Cache miss - make actual request
        stats.cacheMisses += 1
        isLoading = true
        
        let startTime = Date()
        
        do {
            let response = try await client.sendMessage(prompt)
            let responseTime = Date().timeIntervalSince(startTime)
            
            let result = response.choices.first?.message.content ?? ""
            
            // Cache the response if appropriate
            if useCache && policy.enabled && isCacheable(prompt) {
                let key = generateCacheKey(prompt: prompt)
                cacheResponse(
                    key: key,
                    prompt: prompt,
                    response: result,
                    responseTime: responseTime
                )
            }
            
            isLoading = false
            
            return RequestResult(
                response: result,
                fromCache: false,
                responseTime: responseTime,
                cacheKey: nil
            )
            
        } catch {
            isLoading = false
            
            // Try to return cached response on error
            if let key = generateCacheKey(prompt: prompt),
               let cached = getCachedResponse(key: key, ignoreExpiry: true) {
                return RequestResult(
                    response: cached.response,
                    fromCache: true,
                    responseTime: 0,
                    cacheKey: key,
                    error: error.localizedDescription
                )
            }
            
            return RequestResult(
                response: "",
                fromCache: false,
                responseTime: 0,
                cacheKey: nil,
                error: error.localizedDescription
            )
        }
    }
    
    struct RequestResult {
        let response: String
        let fromCache: Bool
        let responseTime: TimeInterval
        let cacheKey: String?
        var error: String?
    }
    
    private func isCacheable(_ prompt: String) -> Bool {
        // Check prompt length
        guard prompt.count >= policy.minPromptLength else { return false }
        
        // Check exclude patterns
        for pattern in policy.excludePatterns {
            if prompt.lowercased().contains(pattern.lowercased()) {
                return false
            }
        }
        
        return true
    }
    
    private func generateCacheKey(prompt: String) -> String {
        // Include relevant parameters in cache key
        let components = [
            prompt,
            "deepseek-chat", // model
            "0.7", // temperature
            "none" // max_tokens
        ]
        
        return components.joined(separator: "|").data(using: .utf8)?.base64EncodedString() ?? prompt
    }
    
    private func getCachedResponse(key: String, ignoreExpiry: Bool = false) -> CacheEntry? {
        guard let index = cache.firstIndex(where: { $0.key == key }) else {
            return nil
        }
        
        var entry = cache[index]
        
        // Check expiry
        if !ignoreExpiry && entry.isExpired {
            return nil
        }
        
        // Update access info
        entry.accessCount += 1
        entry.lastAccessed = Date()
        cache[index] = entry
        
        // Move to front for LRU
        if policy.evictionPolicy == .lru {
            cache.move(fromOffsets: IndexSet(integer: index), toOffset: 0)
        }
        
        saveCache()
        
        return entry
    }
    
    private func cacheResponse(
        key: String,
        prompt: String,
        response: String,
        responseTime: TimeInterval
    ) {
        let size = (prompt.count + response.count) * 2 // Rough estimate
        
        let entry = CacheEntry(
            key: key,
            prompt: prompt,
            response: response,
            size: size,
            metadata: CacheEntry.CacheMetadata(
                model: "deepseek-chat",
                temperature: 0.7,
                maxTokens: nil,
                responseTime: responseTime
            )
        )
        
        // Check cache size and evict if necessary
        ensureCacheSize(newEntrySize: Int64(size))
        
        cache.insert(entry, at: 0)
        updateCacheSize()
        saveCache()
    }
    
    private func ensureCacheSize(newEntrySize: Int64) {
        var currentSize = stats.currentSize
        
        while currentSize + newEntrySize > policy.maxSize && !cache.isEmpty {
            // Evict based on policy
            let indexToRemove: Int
            
            switch policy.evictionPolicy {
            case .lru:
                indexToRemove = cache.count - 1 // Remove last (least recently used)
                
            case .lfu:
                indexToRemove = cache.indices.min { cache[$0].accessCount < cache[$1].accessCount } ?? cache.count - 1
                
            case .fifo:
                indexToRemove = cache.count - 1 // Remove oldest
                
            case .ttl:
                // Remove expired entries first
                if let expiredIndex = cache.firstIndex(where: { $0.isExpired }) {
                    indexToRemove = expiredIndex
                } else {
                    indexToRemove = cache.count - 1
                }
            }
            
            currentSize -= Int64(cache[indexToRemove].size)
            cache.remove(at: indexToRemove)
        }
    }
    
    func clearCache() {
        cache.removeAll()
        stats.currentSize = 0
        saveCache()
    }
    
    func removeExpired() {
        cache.removeAll { $0.isExpired }
        updateCacheSize()
        saveCache()
    }
    
    func removeCacheEntry(_ id: UUID) {
        cache.removeAll { $0.id == id }
        updateCacheSize()
        saveCache()
    }
    
    private func updateCacheSize() {
        stats.currentSize = cache.reduce(0) { $0 + Int64($1.size) }
    }
    
    private func saveCache() {
        // In production, save to disk
        if let encoded = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(encoded, forKey: "response_cache")
        }
    }
    
    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: "response_cache"),
           let decoded = try? JSONDecoder().decode([CacheEntry].self, from: data) {
            cache = decoded
            updateCacheSize()
        }
    }
    
    func preloadCommonPrompts() async {
        let commonPrompts = [
            "What is SwiftUI?",
            "Explain async/await in Swift",
            "How do I use CoreData?",
            "What are Swift actors?",
            "Explain property wrappers"
        ]
        
        for prompt in commonPrompts {
            _ = await sendRequest(prompt)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
        }
    }
}

// UI Components
struct CacheOverviewCard: View {
    @ObservedObject var manager: ResponseCacheManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Response Cache")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(manager.policy.enabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(manager.policy.enabled ? "Enabled" : "Disabled")
                            .font(.subheadline)
                            .foregroundColor(manager.policy.enabled ? .green : .gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(manager.cache.count)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Cached Items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Storage usage
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Storage Used")
                        .font(.caption)
                    Spacer()
                    Text("\(formatBytes(manager.stats.currentSize)) / \(formatBytes(manager.policy.maxSize))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: Double(manager.stats.currentSize), total: Double(manager.policy.maxSize))
                    .tint(storageColor)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var storageColor: Color {
        let usage = Double(manager.stats.currentSize) / Double(manager.policy.maxSize)
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

struct CacheHitRateView: View {
    @ObservedObject var manager: ResponseCacheManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cache Performance")
                .font(.headline)
            
            // Hit rate gauge
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .rotationEffect(.degrees(135))
                
                Circle()
                    .trim(from: 0, to: 0.75 * manager.stats.hitRate)
                    .stroke(hitRateColor, lineWidth: 20)
                    .rotationEffect(.degrees(135))
                
                VStack {
                    Text(String(format: "%.0f%%", manager.stats.hitRate * 100))
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Hit Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 120)
            
            // Statistics
            HStack(spacing: 20) {
                CacheStatView(
                    label: "Total Requests",
                    value: "\(manager.stats.totalRequests)"
                )
                
                CacheStatView(
                    label: "Cache Hits",
                    value: "\(manager.stats.cacheHits)",
                    color: .green
                )
                
                CacheStatView(
                    label: "Cache Misses",
                    value: "\(manager.stats.cacheMisses)",
                    color: .red
                )
            }
            
            if manager.stats.averageTimeSaved > 0 {
                Label(
                    "Average time saved: \(String(format: "%.2f", manager.stats.averageTimeSaved))s",
                    systemImage: "timer"
                )
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    var hitRateColor: Color {
        if manager.stats.hitRate > 0.7 {
            return .green
        } else if manager.stats.hitRate > 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

struct CacheStatView: View {
    let label: String
    let value: String
    var color: Color = .primary
    
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

struct CacheTestControls: View {
    @ObservedObject var manager: ResponseCacheManager
    @Binding var testPrompt: String
    @State private var lastResult: ResponseCacheManager.RequestResult?
    @State private var useCache = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Cache")
                .font(.headline)
            
            TextField("Enter prompt", text: $testPrompt)
                .textFieldStyle(.roundedBorder)
            
            Toggle("Use cache", isOn: $useCache)
            
            HStack {
                Button("Send Request") {
                    Task {
                        lastResult = await manager.sendRequest(testPrompt, useCache: useCache)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.isLoading)
                
                if manager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Result display
            if let result = lastResult {
                ResultView(result: result)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ResultView: View {
    let result: ResponseCacheManager.RequestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    result.fromCache ? "From Cache" : "From API",
                    systemImage: result.fromCache ? "archivebox.fill" : "network"
                )
                .font(.caption)
                .foregroundColor(result.fromCache ? .green : .blue)
                
                Spacer()
                
                if !result.fromCache {
                    Text("\(String(format: "%.2f", result.responseTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = result.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if !result.response.isEmpty {
                Text(result.response)
                    .font(.caption)
                    .lineLimit(3)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(result.fromCache ? Color.green.opacity(0.05) : Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

struct CachedItemsList: View {
    @ObservedObject var manager: ResponseCacheManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cached Items")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear All", role: .destructive) {
                    manager.clearCache()
                }
                .font(.caption)
            }
            
            if manager.cache.isEmpty {
                Text("No cached items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(manager.cache) { entry in
                    CachedItemRow(entry: entry, manager: manager)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct CachedItemRow: View {
    let entry: ResponseCacheManager.CacheEntry
    @ObservedObject var manager: ResponseCacheManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.prompt)
                        .font(.caption)
                        .lineLimit(1)
                    
                    HStack {
                        Text(entry.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• \(entry.accessCount) hits")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        if entry.isExpired {
                            Text("• Expired")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(entry.response)
                        .font(.caption)
                        .lineLimit(5)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    
                    HStack {
                        Label("\(formatBytes(Int64(entry.size)))", systemImage: "doc")
                        Label("\(String(format: "%.2fs saved", entry.metadata.responseTime))", systemImage: "timer")
                        
                        Spacer()
                        
                        Button("Remove", role: .destructive) {
                            manager.removeCacheEntry(entry.id)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    .font(.caption2)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

struct CachePoliciesView: View {
    @ObservedObject var manager: ResponseCacheManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cache Policies")
                .font(.headline)
            
            Toggle("Enable caching", isOn: $manager.policy.enabled)
            
            // Eviction policy
            Picker("Eviction Policy", selection: $manager.policy.evictionPolicy) {
                ForEach(ResponseCacheManager.CachePolicy.EvictionPolicy.allCases, id: \.self) { policy in
                    Text(policy.rawValue).tag(policy)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            // Max age
            HStack {
                Text("Max Age:")
                Slider(
                    value: Binding(
                        get: { manager.policy.maxAge / 3600 },
                        set: { manager.policy.maxAge = $0 * 3600 }
                    ),
                    in: 1...168, // 1 hour to 1 week
                    step: 1
                )
                Text("\(Int(manager.policy.maxAge / 3600)) hours")
                    .frame(width: 80)
            }
            
            // Min prompt length
            HStack {
                Text("Min Prompt Length:")
                Stepper("\(manager.policy.minPromptLength) chars", 
                       value: $manager.policy.minPromptLength, 
                       in: 5...50,
                       step: 5)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct CacheManagementView: View {
    @ObservedObject var manager: ResponseCacheManager
    @State private var isPreloading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Management")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button("Remove Expired") {
                    manager.removeExpired()
                }
                .buttonStyle(.bordered)
                
                Button("Preload Common") {
                    isPreloading = true
                    Task {
                        await manager.preloadCommonPrompts()
                        isPreloading = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isPreloading)
                
                if isPreloading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}