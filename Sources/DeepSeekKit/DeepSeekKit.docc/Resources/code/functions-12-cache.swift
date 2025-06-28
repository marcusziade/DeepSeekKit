import SwiftUI
import DeepSeekKit
import CryptoKit

// Function result caching system
class FunctionResultCache: ObservableObject {
    @Published var cacheStats = CacheStatistics()
    @Published var entries: [CacheEntry] = []
    
    private let memoryCache = NSCache<NSString, CacheValue>()
    private let diskCacheURL: URL
    private let maxMemorySize: Int = 10 * 1024 * 1024 // 10 MB
    private let maxDiskSize: Int = 100 * 1024 * 1024 // 100 MB
    
    struct CacheEntry: Identifiable {
        let id = UUID()
        let key: String
        let functionName: String
        let arguments: [String: Any]
        let result: String
        let timestamp: Date
        let expiresAt: Date
        let size: Int
        let hitCount: Int
        
        var isExpired: Bool {
            Date() > expiresAt
        }
    }
    
    struct CacheStatistics {
        var totalRequests: Int = 0
        var cacheHits: Int = 0
        var cacheMisses: Int = 0
        var memoryUsage: Int = 0
        var diskUsage: Int = 0
        var evictions: Int = 0
        
        var hitRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(cacheHits) / Double(totalRequests)
        }
    }
    
    class CacheValue: NSObject {
        let data: Data
        let metadata: CacheMetadata
        
        init(data: Data, metadata: CacheMetadata) {
            self.data = data
            self.metadata = metadata
        }
    }
    
    struct CacheMetadata: Codable {
        let functionName: String
        let arguments: String // JSON string
        let result: String
        let timestamp: Date
        let expiresAt: Date
        let size: Int
        var hitCount: Int
    }
    
    init() {
        // Setup disk cache directory
        let cacheDir = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!
        self.diskCacheURL = cacheDir.appendingPathComponent("FunctionCache")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: diskCacheURL,
            withIntermediateDirectories: true
        )
        
        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = maxMemorySize
        
        // Load cache index
        loadCacheIndex()
        
        // Start cleanup timer
        startCleanupTimer()
    }
    
    // MARK: - Cache Key Generation
    
    private func generateCacheKey(
        functionName: String,
        arguments: [String: Any]
    ) -> String {
        // Sort arguments for consistent key generation
        let sortedArgs = arguments.sorted { $0.key < $1.key }
        let argsString = sortedArgs.map { "\($0.key):\($0.value)" }.joined(separator: ",")
        
        let input = "\(functionName)|\(argsString)"
        
        // Generate SHA256 hash
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Cache Operations
    
    func get(
        functionName: String,
        arguments: [String: Any]
    ) -> String? {
        let key = generateCacheKey(functionName: functionName, arguments: arguments)
        cacheStats.totalRequests += 1
        
        // Check memory cache first
        if let cacheValue = memoryCache.object(forKey: key as NSString) {
            if cacheValue.metadata.expiresAt > Date() {
                cacheStats.cacheHits += 1
                updateHitCount(for: key)
                return cacheValue.metadata.result
            } else {
                // Expired, remove from cache
                memoryCache.removeObject(forKey: key as NSString)
            }
        }
        
        // Check disk cache
        if let diskResult = loadFromDisk(key: key) {
            cacheStats.cacheHits += 1
            
            // Promote to memory cache
            if let data = diskResult.data(using: .utf8) {
                let metadata = CacheMetadata(
                    functionName: functionName,
                    arguments: String(describing: arguments),
                    result: diskResult,
                    timestamp: Date(),
                    expiresAt: Date().addingTimeInterval(3600),
                    size: data.count,
                    hitCount: 1
                )
                let cacheValue = CacheValue(data: data, metadata: metadata)
                memoryCache.setObject(cacheValue, forKey: key as NSString, cost: data.count)
            }
            
            return diskResult
        }
        
        cacheStats.cacheMisses += 1
        return nil
    }
    
    func set(
        functionName: String,
        arguments: [String: Any],
        result: String,
        ttl: TimeInterval = 3600 // 1 hour default
    ) {
        let key = generateCacheKey(functionName: functionName, arguments: arguments)
        let data = Data(result.utf8)
        
        let metadata = CacheMetadata(
            functionName: functionName,
            arguments: String(describing: arguments),
            result: result,
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(ttl),
            size: data.count,
            hitCount: 0
        )
        
        // Add to memory cache
        let cacheValue = CacheValue(data: data, metadata: metadata)
        memoryCache.setObject(cacheValue, forKey: key as NSString, cost: data.count)
        
        // Add to disk cache
        saveToDisk(key: key, metadata: metadata)
        
        // Update entries list
        updateEntries()
        
        // Update stats
        cacheStats.memoryUsage = calculateMemoryUsage()
        cacheStats.diskUsage = calculateDiskUsage()
    }
    
    func invalidate(functionName: String? = nil) {
        if let functionName = functionName {
            // Invalidate specific function
            invalidateFunction(functionName)
        } else {
            // Clear all cache
            clearCache()
        }
    }
    
    private func invalidateFunction(_ functionName: String) {
        // Remove from memory cache
        let allKeys = entries.filter { $0.functionName == functionName }.map { $0.key }
        for key in allKeys {
            memoryCache.removeObject(forKey: key as NSString)
            removeFromDisk(key: key)
        }
        
        updateEntries()
        cacheStats.evictions += allKeys.count
    }
    
    private func clearCache() {
        memoryCache.removeAllObjects()
        
        // Clear disk cache
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(
            at: diskCacheURL,
            withIntermediateDirectories: true
        )
        
        entries.removeAll()
        cacheStats = CacheStatistics()
    }
    
    // MARK: - Disk Operations
    
    private func saveToDisk(key: String, metadata: CacheMetadata) {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        do {
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save cache to disk: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> String? {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let metadata = try JSONDecoder().decode(CacheMetadata.self, from: data)
            
            if metadata.expiresAt > Date() {
                return metadata.result
            } else {
                // Expired, remove from disk
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Failed to load cache from disk: \(error)")
        }
        
        return nil
    }
    
    private func removeFromDisk(key: String) {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Cache Management
    
    private func updateHitCount(for key: String) {
        if var entry = entries.first(where: { $0.key == key }) {
            entry = CacheEntry(
                key: entry.key,
                functionName: entry.functionName,
                arguments: entry.arguments,
                result: entry.result,
                timestamp: entry.timestamp,
                expiresAt: entry.expiresAt,
                size: entry.size,
                hitCount: entry.hitCount + 1
            )
        }
    }
    
    private func updateEntries() {
        var newEntries: [CacheEntry] = []
        
        // Get all cache keys
        let enumerator = FileManager.default.enumerator(at: diskCacheURL, includingPropertiesForKeys: nil)
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if let data = try? Data(contentsOf: fileURL),
               let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: data),
               let arguments = try? JSONSerialization.jsonObject(with: Data(metadata.arguments.utf8)) as? [String: Any] {
                
                let entry = CacheEntry(
                    key: fileURL.lastPathComponent,
                    functionName: metadata.functionName,
                    arguments: arguments,
                    result: metadata.result,
                    timestamp: metadata.timestamp,
                    expiresAt: metadata.expiresAt,
                    size: metadata.size,
                    hitCount: metadata.hitCount
                )
                newEntries.append(entry)
            }
        }
        
        entries = newEntries.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func calculateMemoryUsage() -> Int {
        // Approximate memory usage
        return entries.reduce(0) { $0 + $1.size }
    }
    
    private func calculateDiskUsage() -> Int {
        let enumerator = FileManager.default.enumerator(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        
        var totalSize = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    private func loadCacheIndex() {
        updateEntries()
        cacheStats.memoryUsage = calculateMemoryUsage()
        cacheStats.diskUsage = calculateDiskUsage()
    }
    
    // MARK: - Cleanup
    
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.cleanupExpiredEntries()
        }
    }
    
    private func cleanupExpiredEntries() {
        let expiredKeys = entries.filter { $0.isExpired }.map { $0.key }
        
        for key in expiredKeys {
            memoryCache.removeObject(forKey: key as NSString)
            removeFromDisk(key: key)
        }
        
        if !expiredKeys.isEmpty {
            updateEntries()
            cacheStats.evictions += expiredKeys.count
        }
    }
}

// MARK: - Cache-aware Function Executor

class CachedFunctionExecutor: ObservableObject {
    @Published var isExecuting = false
    @Published var lastResult: String?
    @Published var cacheUsed = false
    
    private let cache = FunctionResultCache()
    private let executor = FunctionExecutor()
    
    func execute(
        functionName: String,
        arguments: [String: Any],
        ttl: TimeInterval = 3600,
        forceRefresh: Bool = false
    ) async -> String {
        isExecuting = true
        cacheUsed = false
        
        // Check cache first (unless force refresh)
        if !forceRefresh,
           let cachedResult = cache.get(functionName: functionName, arguments: arguments) {
            cacheUsed = true
            lastResult = cachedResult
            isExecuting = false
            return cachedResult
        }
        
        // Execute function
        let result = await executeFunction(functionName: functionName, arguments: arguments)
        
        // Cache result
        cache.set(
            functionName: functionName,
            arguments: arguments,
            result: result,
            ttl: ttl
        )
        
        lastResult = result
        isExecuting = false
        return result
    }
    
    private func executeFunction(
        functionName: String,
        arguments: [String: Any]
    ) async -> String {
        // Simulate function execution
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        switch functionName {
        case "get_weather":
            let location = arguments["location"] as? String ?? "Unknown"
            return "Weather in \(location): 72°F, Sunny"
            
        case "calculate":
            let expression = arguments["expression"] as? String ?? "0"
            return "Result: \(expression) = 42"
            
        case "search":
            let query = arguments["query"] as? String ?? ""
            return "Found 10 results for '\(query)'"
            
        default:
            return "Function '\(functionName)' executed successfully"
        }
    }
    
    var cacheStats: FunctionResultCache.CacheStatistics {
        cache.cacheStats
    }
    
    var cacheEntries: [FunctionResultCache.CacheEntry] {
        cache.entries
    }
    
    func invalidateCache(functionName: String? = nil) {
        cache.invalidate(functionName: functionName)
    }
}

// MARK: - Cache Management UI

struct FunctionCacheView: View {
    @StateObject private var cachedExecutor = CachedFunctionExecutor()
    @State private var selectedFunction = "get_weather"
    @State private var argumentsJSON = """
    {
        "location": "San Francisco, CA"
    }
    """
    @State private var ttl: TimeInterval = 3600
    @State private var forceRefresh = false
    
    let functionOptions = ["get_weather", "calculate", "search"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cache statistics
                CacheStatsCard(stats: cachedExecutor.cacheStats)
                
                // Function execution
                FunctionExecutionCard(
                    selectedFunction: $selectedFunction,
                    argumentsJSON: $argumentsJSON,
                    ttl: $ttl,
                    forceRefresh: $forceRefresh,
                    functionOptions: functionOptions,
                    isExecuting: cachedExecutor.isExecuting,
                    lastResult: cachedExecutor.lastResult,
                    cacheUsed: cachedExecutor.cacheUsed,
                    onExecute: executeFunctionWithCache
                )
                
                // Cache entries
                CacheEntriesView(
                    entries: cachedExecutor.cacheEntries,
                    onInvalidate: { functionName in
                        cachedExecutor.invalidateCache(functionName: functionName)
                    }
                )
            }
            .padding()
        }
        .navigationTitle("Function Cache")
    }
    
    private func executeFunctionWithCache() {
        guard let arguments = parseArguments() else { return }
        
        Task {
            _ = await cachedExecutor.execute(
                functionName: selectedFunction,
                arguments: arguments,
                ttl: ttl,
                forceRefresh: forceRefresh
            )
        }
    }
    
    private func parseArguments() -> [String: Any]? {
        guard let data = argumentsJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

struct CacheStatsCard: View {
    let stats: FunctionResultCache.CacheStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Statistics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatItem(
                    title: "Hit Rate",
                    value: String(format: "%.1f%%", stats.hitRate * 100),
                    color: stats.hitRate > 0.5 ? .green : .orange
                )
                
                StatItem(
                    title: "Total Requests",
                    value: "\(stats.totalRequests)",
                    color: .blue
                )
                
                StatItem(
                    title: "Cache Hits",
                    value: "\(stats.cacheHits)",
                    color: .green
                )
                
                StatItem(
                    title: "Cache Misses",
                    value: "\(stats.cacheMisses)",
                    color: .red
                )
                
                StatItem(
                    title: "Memory Usage",
                    value: formatBytes(stats.memoryUsage),
                    color: .purple
                )
                
                StatItem(
                    title: "Disk Usage",
                    value: formatBytes(stats.diskUsage),
                    color: .indigo
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct FunctionExecutionCard: View {
    @Binding var selectedFunction: String
    @Binding var argumentsJSON: String
    @Binding var ttl: TimeInterval
    @Binding var forceRefresh: Bool
    
    let functionOptions: [String]
    let isExecuting: Bool
    let lastResult: String?
    let cacheUsed: Bool
    let onExecute: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Execute Function")
                .font(.headline)
            
            Picker("Function", selection: $selectedFunction) {
                ForEach(functionOptions, id: \.self) { function in
                    Text(function).tag(function)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack(alignment: .leading) {
                Text("Arguments (JSON)")
                    .font(.subheadline)
                
                TextEditor(text: $argumentsJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .padding(4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("TTL (seconds)")
                        .font(.caption)
                    
                    TextField("TTL", value: $ttl, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                }
                
                Spacer()
                
                Toggle("Force Refresh", isOn: $forceRefresh)
            }
            
            Button(action: onExecute) {
                if isExecuting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Executing...")
                    }
                } else {
                    Text("Execute")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExecuting)
            
            if let result = lastResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Result")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if cacheUsed {
                            Label("From Cache", systemImage: "memorychip")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(result)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CacheEntriesView: View {
    let entries: [FunctionResultCache.CacheEntry]
    let onInvalidate: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Cache Entries")
                    .font(.headline)
                
                Spacer()
                
                if !entries.isEmpty {
                    Button("Clear All") {
                        onInvalidate("")
                    }
                    .foregroundColor(.red)
                }
            }
            
            if entries.isEmpty {
                Text("No cached entries")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(entries) { entry in
                    CacheEntryRow(entry: entry) {
                        onInvalidate(entry.functionName)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CacheEntryRow: View {
    let entry: FunctionResultCache.CacheEntry
    let onInvalidate: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.functionName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Label("\(entry.hitCount) hits", systemImage: "arrow.clockwise")
                        
                        Label(formatBytes(entry.size), systemImage: "doc")
                        
                        if entry.isExpired {
                            Label("Expired", systemImage: "clock.badge.xmark")
                                .foregroundColor(.red)
                        } else {
                            Label(timeRemaining, systemImage: "clock")
                                .foregroundColor(.green)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(String(describing: entry.arguments))
                        .font(.caption)
                        .padding(4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    HStack {
                        Button("Invalidate") {
                            onInvalidate()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
                .padding(.leading)
            }
        }
        .padding()
        .background(entry.isExpired ? Color.red.opacity(0.1) : Color(.systemGray5))
        .cornerRadius(8)
    }
    
    private var timeRemaining: String {
        let remaining = entry.expiresAt.timeIntervalSince(Date())
        if remaining < 60 {
            return "\(Int(remaining))s"
        } else if remaining < 3600 {
            return "\(Int(remaining / 60))m"
        } else {
            return "\(Int(remaining / 3600))h"
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return "\(bytes / 1024) KB"
        } else {
            return "\(bytes / (1024 * 1024)) MB"
        }
    }
}