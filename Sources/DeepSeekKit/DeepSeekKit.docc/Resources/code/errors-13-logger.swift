import SwiftUI
import DeepSeekKit
import os.log

// Creating an error logger
struct ErrorLoggerView: View {
    @StateObject private var errorLogger = ErrorLogger()
    @State private var selectedLogLevel: LogLevel = .error
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Error Logger")
                .font(.largeTitle)
                .bold()
            
            // Logger controls
            LoggerControlsView(
                logger: errorLogger,
                selectedLevel: $selectedLogLevel
            )
            
            // Log statistics
            LogStatisticsView(logger: errorLogger)
            
            // Search and filters
            LogSearchView(
                searchText: $searchText,
                logger: errorLogger
            )
            
            // Log entries
            LogEntriesView(
                logger: errorLogger,
                searchText: searchText,
                selectedLevel: selectedLogLevel
            )
            
            // Export options
            LogExportView(logger: errorLogger)
        }
        .padding()
    }
}

// Log levels
enum LogLevel: String, CaseIterable {
    case debug = "Debug"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .debug: return "ant.circle"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// Error logger
@MainActor
class ErrorLogger: ObservableObject {
    @Published var logEntries: [LogEntry] = []
    @Published var isLogging = true
    @Published var logToConsole = true
    @Published var logToFile = true
    @Published var maxLogEntries = 1000
    
    private let logger = Logger(subsystem: "com.deepseek.kit", category: "ErrorLogger")
    private let client = DeepSeekClient()
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let level: LogLevel
        let category: LogCategory
        let message: String
        let details: [String: Any]?
        let stackTrace: String?
        let userInfo: UserInfo?
        
        enum LogCategory: String, CaseIterable {
            case network = "Network"
            case api = "API"
            case authentication = "Authentication"
            case cache = "Cache"
            case stream = "Stream"
            case general = "General"
            
            var icon: String {
                switch self {
                case .network: return "network"
                case .api: return "server.rack"
                case .authentication: return "lock"
                case .cache: return "archivebox"
                case .stream: return "dot.radiowaves.left.and.right"
                case .general: return "gear"
                }
            }
        }
        
        struct UserInfo {
            let userId: String?
            let sessionId: String
            let appVersion: String
            let osVersion: String
            let deviceModel: String
        }
    }
    
    init() {
        setupLogger()
        generateSampleLogs()
    }
    
    private func setupLogger() {
        // Configure logging
        if logToFile {
            setupFileLogging()
        }
    }
    
    private func setupFileLogging() {
        // In production, set up file logging
        // This would write to Documents directory or app container
    }
    
    func log(
        _ message: String,
        level: LogLevel,
        category: LogEntry.LogCategory,
        error: Error? = nil,
        details: [String: Any]? = nil
    ) {
        guard isLogging else { return }
        
        // Create log entry
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            details: details,
            stackTrace: error != nil ? Thread.callStackSymbols.joined(separator: "\n") : nil,
            userInfo: getCurrentUserInfo()
        )
        
        // Add to entries (with limit)
        logEntries.insert(entry, at: 0)
        if logEntries.count > maxLogEntries {
            logEntries = Array(logEntries.prefix(maxLogEntries))
        }
        
        // Log to console
        if logToConsole {
            logToConsole(entry: entry)
        }
        
        // Log to file
        if logToFile {
            logToFile(entry: entry)
        }
        
        // Send critical errors to monitoring service
        if level == .critical {
            sendToMonitoring(entry: entry)
        }
    }
    
    private func logToConsole(entry: LogEntry) {
        let detailsString = entry.details?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? ""
        
        logger.log(
            level: entry.level.osLogType,
            "[\(entry.category.rawValue)] \(entry.message) \(detailsString)"
        )
    }
    
    private func logToFile(entry: LogEntry) {
        // Implementation for file logging
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: entry.timestamp)
        
        let logLine = "\(timestamp) [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)\n"
        
        // Write to file in production
    }
    
    private func sendToMonitoring(entry: LogEntry) {
        // Send critical errors to monitoring service
        // This could be Crashlytics, Sentry, etc.
    }
    
    private func getCurrentUserInfo() -> LogEntry.UserInfo {
        LogEntry.UserInfo(
            userId: nil, // Get from user session
            sessionId: UUID().uuidString,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: getDeviceModel()
        )
    }
    
    private func getDeviceModel() -> String {
        #if os(iOS)
        return UIDevice.current.model
        #else
        return "Mac"
        #endif
    }
    
    // API error logging
    func logAPIError(_ error: DeepSeekError, request: String? = nil) {
        let details: [String: Any] = [
            "error_type": String(describing: error),
            "request": request ?? "N/A"
        ]
        
        switch error {
        case .authenticationError:
            log(
                "Authentication failed",
                level: .error,
                category: .authentication,
                error: error,
                details: details
            )
            
        case .rateLimitExceeded:
            log(
                "Rate limit exceeded",
                level: .warning,
                category: .api,
                error: error,
                details: details
            )
            
        case .networkError(let underlyingError):
            log(
                "Network error: \(underlyingError.localizedDescription)",
                level: .error,
                category: .network,
                error: error,
                details: details
            )
            
        case .apiError(let code, let message):
            let level: LogLevel = code >= 500 ? .critical : .error
            log(
                "API error \(code): \(message ?? "Unknown")",
                level: level,
                category: .api,
                error: error,
                details: details
            )
            
        default:
            log(
                "Unknown error: \(error)",
                level: .error,
                category: .general,
                error: error,
                details: details
            )
        }
    }
    
    // Generate sample logs for demonstration
    private func generateSampleLogs() {
        let sampleLogs: [(String, LogLevel, LogEntry.LogCategory)] = [
            ("Application started", .info, .general),
            ("Connected to DeepSeek API", .info, .network),
            ("Cache initialized with 50 entries", .debug, .cache),
            ("Authentication successful", .info, .authentication),
            ("Rate limit warning: 80% of quota used", .warning, .api),
            ("Network timeout after 30s", .error, .network),
            ("Stream connection established", .info, .stream),
            ("Cache hit for prompt: 'What is SwiftUI?'", .debug, .cache),
            ("API returned 429 Too Many Requests", .error, .api),
            ("Critical: Server returned 503 Service Unavailable", .critical, .api)
        ]
        
        for (message, level, category) in sampleLogs {
            log(message, level: level, category: category)
        }
    }
    
    // Log analysis
    func getLogStatistics() -> LogStatistics {
        var stats = LogStatistics()
        
        for entry in logEntries {
            stats.totalLogs += 1
            stats.logsByLevel[entry.level, default: 0] += 1
            stats.logsByCategory[entry.category, default: 0] += 1
            
            if entry.level == .error || entry.level == .critical {
                stats.errorCount += 1
            }
        }
        
        // Calculate error rate
        let recentLogs = logEntries.prefix(100)
        let recentErrors = recentLogs.filter { $0.level == .error || $0.level == .critical }.count
        stats.errorRate = Double(recentErrors) / Double(max(recentLogs.count, 1))
        
        return stats
    }
    
    struct LogStatistics {
        var totalLogs = 0
        var errorCount = 0
        var errorRate = 0.0
        var logsByLevel: [LogLevel: Int] = [:]
        var logsByCategory: [LogEntry.LogCategory: Int] = [:]
    }
    
    // Export functions
    func exportLogs(format: ExportFormat) -> String {
        switch format {
        case .json:
            return exportAsJSON()
        case .csv:
            return exportAsCSV()
        case .plainText:
            return exportAsPlainText()
        }
    }
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case plainText = "Plain Text"
    }
    
    private func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let exportData = logEntries.map { entry in
            [
                "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                "level": entry.level.rawValue,
                "category": entry.category.rawValue,
                "message": entry.message
            ]
        }
        
        if let data = try? encoder.encode(exportData),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return "[]"
    }
    
    private func exportAsCSV() -> String {
        var csv = "Timestamp,Level,Category,Message\n"
        
        for entry in logEntries {
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            let message = entry.message.replacingOccurrences(of: ",", with: ";")
            csv += "\(timestamp),\(entry.level.rawValue),\(entry.category.rawValue),\"\(message)\"\n"
        }
        
        return csv
    }
    
    private func exportAsPlainText() -> String {
        logEntries.map { entry in
            let timestamp = DateFormatter.localizedString(from: entry.timestamp, dateStyle: .short, timeStyle: .medium)
            return "\(timestamp) [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

// UI Components
struct LoggerControlsView: View {
    @ObservedObject var logger: ErrorLogger
    @Binding var selectedLevel: LogLevel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Logger Controls")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Enable Logging", isOn: $logger.isLogging)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
            }
            
            HStack {
                Toggle("Console", isOn: $logger.logToConsole)
                Toggle("File", isOn: $logger.logToFile)
            }
            .font(.caption)
            
            // Log level filter
            Picker("Filter Level", selection: $selectedLevel) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Label(level.rawValue, systemImage: level.icon)
                        .tag(level)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct LogStatisticsView: View {
    @ObservedObject var logger: ErrorLogger
    
    var body: some View {
        let stats = logger.getLogStatistics()
        
        VStack(alignment: .leading, spacing: 16) {
            Text("Log Statistics")
                .font(.headline)
            
            // Overview cards
            HStack(spacing: 12) {
                StatCard(
                    title: "Total Logs",
                    value: "\(stats.totalLogs)",
                    icon: "doc.text",
                    color: .blue
                )
                
                StatCard(
                    title: "Errors",
                    value: "\(stats.errorCount)",
                    icon: "exclamationmark.circle",
                    color: .red
                )
                
                StatCard(
                    title: "Error Rate",
                    value: String(format: "%.1f%%", stats.errorRate * 100),
                    icon: "percent",
                    color: stats.errorRate > 0.1 ? .red : .green
                )
            }
            
            // Level distribution
            VStack(alignment: .leading, spacing: 8) {
                Text("By Level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(LogLevel.allCases, id: \.self) { level in
                    if let count = stats.logsByLevel[level], count > 0 {
                        HStack {
                            Image(systemName: level.icon)
                                .foregroundColor(level.color)
                                .frame(width: 20)
                            
                            Text(level.rawValue)
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(level.color)
                                    .frame(width: geometry.size.width * (Double(count) / Double(stats.totalLogs)))
                            }
                            .frame(height: 16)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            
                            Text("\(count)")
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct StatCard: View {
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

struct LogSearchView: View {
    @Binding var searchText: String
    @ObservedObject var logger: ErrorLogger
    @State private var selectedCategory: ErrorLogger.LogEntry.LogCategory?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(
                        category: nil,
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )
                    
                    ForEach(ErrorLogger.LogEntry.LogCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct CategoryChip: View {
    let category: ErrorLogger.LogEntry.LogCategory?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let category = category {
                    Image(systemName: category.icon)
                    Text(category.rawValue)
                } else {
                    Text("All")
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct LogEntriesView: View {
    @ObservedObject var logger: ErrorLogger
    let searchText: String
    let selectedLevel: LogLevel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                }
            }
        }
        .frame(maxHeight: 400)
    }
    
    var filteredEntries: [ErrorLogger.LogEntry] {
        logger.logEntries.filter { entry in
            // Filter by level
            if entry.level.rawValue < selectedLevel.rawValue {
                return false
            }
            
            // Filter by search
            if !searchText.isEmpty {
                return entry.message.localizedCaseInsensitiveContains(searchText) ||
                       entry.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
            
            return true
        }
    }
}

struct LogEntryRow: View {
    let entry: ErrorLogger.LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.level.icon)
                    .foregroundColor(entry.level.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.message)
                        .font(.caption)
                        .lineLimit(isExpanded ? nil : 1)
                    
                    HStack {
                        Text(entry.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Label(entry.category.rawValue, systemImage: entry.category.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if entry.details != nil || entry.stackTrace != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let details = entry.details {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Details:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            ForEach(Array(details.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text("\(key):")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("\(String(describing: details[key] ?? ""))")
                                        .font(.caption2)
                                        .fontFamily(.monospaced)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    if let stackTrace = entry.stackTrace {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stack Trace:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(stackTrace)
                                    .font(.caption2)
                                    .fontFamily(.monospaced)
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(entry.level == .critical ? Color.red.opacity(0.05) : Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct LogExportView: View {
    @ObservedObject var logger: ErrorLogger
    @State private var selectedFormat: ErrorLogger.ExportFormat = .json
    @State private var showExportSheet = false
    @State private var exportedData = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Logs")
                .font(.headline)
            
            HStack {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ErrorLogger.ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Button("Export") {
                    exportedData = logger.exportLogs(format: selectedFormat)
                    showExportSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [exportedData])
        }
    }
}

// Share sheet for exporting
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}