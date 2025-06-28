import SwiftUI
import DeepSeekKit

// Error reporting to analytics services
struct ErrorReportingView: View {
    @StateObject private var errorReporter = ErrorReporter()
    @State private var showReportDetails = false
    @State private var selectedService: AnalyticsService = .crashlytics
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Error Reporting")
                    .font(.largeTitle)
                    .bold()
                
                // Reporting overview
                ReportingOverview(reporter: errorReporter)
                
                // Analytics services
                AnalyticsServicesView(
                    reporter: errorReporter,
                    selectedService: $selectedService
                )
                
                // Error aggregation
                ErrorAggregationView(reporter: errorReporter)
                
                // Recent reports
                RecentReportsView(
                    reporter: errorReporter,
                    showDetails: $showReportDetails
                )
                
                // Reporting configuration
                ReportingConfigurationView(reporter: errorReporter)
                
                // Test reporting
                TestReportingView(
                    reporter: errorReporter,
                    service: selectedService
                )
            }
            .padding()
        }
    }
}

// Analytics service types
enum AnalyticsService: String, CaseIterable {
    case crashlytics = "Firebase Crashlytics"
    case sentry = "Sentry"
    case bugsnag = "Bugsnag"
    case appCenter = "App Center"
    case custom = "Custom Backend"
    
    var icon: String {
        switch self {
        case .crashlytics: return "flame"
        case .sentry: return "shield.lefthalf.fill"
        case .bugsnag: return "ant.fill"
        case .appCenter: return "square.stack.3d.up"
        case .custom: return "server.rack"
        }
    }
    
    var color: Color {
        switch self {
        case .crashlytics: return .orange
        case .sentry: return .purple
        case .bugsnag: return .blue
        case .appCenter: return .indigo
        case .custom: return .green
        }
    }
}

// Error reporter
@MainActor
class ErrorReporter: ObservableObject {
    @Published var reports: [ErrorReport] = []
    @Published var aggregatedErrors: [AggregatedError] = []
    @Published var reportingEnabled = true
    @Published var configuration = ReportingConfiguration()
    @Published var stats = ReportingStats()
    @Published var isReporting = false
    
    private let client = DeepSeekClient()
    
    struct ErrorReport: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let error: ErrorInfo
        let context: ErrorContext
        let metadata: ReportMetadata
        var reportedTo: [AnalyticsService] = []
        var status: ReportStatus = .pending
        
        struct ErrorInfo {
            let type: String
            let message: String
            let code: Int?
            let stackTrace: [String]
            let severity: Severity
            
            enum Severity: String, CaseIterable {
                case info = "Info"
                case warning = "Warning"
                case error = "Error"
                case fatal = "Fatal"
                
                var color: Color {
                    switch self {
                    case .info: return .blue
                    case .warning: return .orange
                    case .error: return .red
                    case .fatal: return .purple
                    }
                }
                
                var icon: String {
                    switch self {
                    case .info: return "info.circle"
                    case .warning: return "exclamationmark.triangle"
                    case .error: return "xmark.circle"
                    case .fatal: return "exclamationmark.octagon"
                    }
                }
            }
        }
        
        struct ErrorContext {
            let userId: String?
            let sessionId: String
            let deviceInfo: DeviceInfo
            let appState: AppState
            let networkInfo: NetworkInfo
            let customData: [String: Any]
            
            struct DeviceInfo {
                let model: String
                let osVersion: String
                let appVersion: String
                let buildNumber: String
                let freeMemory: Int64
                let diskSpace: Int64
                let batteryLevel: Float
                let isJailbroken: Bool
            }
            
            struct AppState {
                let viewHierarchy: String
                let memoryUsage: Int64
                let cpuUsage: Double
                let activeRequests: Int
                let sessionDuration: TimeInterval
                let lastAction: String?
            }
            
            struct NetworkInfo {
                let connectionType: String
                let carrier: String?
                let signalStrength: Int?
                let isReachable: Bool
            }
        }
        
        struct ReportMetadata {
            let fingerprint: String // For deduplication
            let tags: [String]
            let breadcrumbs: [Breadcrumb]
            let attachments: [Attachment]
            
            struct Breadcrumb {
                let timestamp: Date
                let category: String
                let message: String
                let level: String
                let data: [String: Any]?
            }
            
            struct Attachment {
                let name: String
                let data: Data
                let mimeType: String
            }
        }
        
        enum ReportStatus: String {
            case pending = "Pending"
            case reporting = "Reporting"
            case reported = "Reported"
            case failed = "Failed"
            case ignored = "Ignored"
            
            var color: Color {
                switch self {
                case .pending: return .gray
                case .reporting: return .blue
                case .reported: return .green
                case .failed: return .red
                case .ignored: return .orange
                }
            }
        }
    }
    
    struct AggregatedError: Identifiable {
        let id = UUID()
        let fingerprint: String
        let firstSeen: Date
        let lastSeen: Date
        var occurrences: Int
        var affectedUsers: Set<String>
        let errorType: String
        let errorMessage: String
        var trend: Trend
        
        enum Trend {
            case increasing
            case stable
            case decreasing
            case resolved
            
            var icon: String {
                switch self {
                case .increasing: return "arrow.up.circle.fill"
                case .stable: return "equal.circle.fill"
                case .decreasing: return "arrow.down.circle.fill"
                case .resolved: return "checkmark.circle.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .increasing: return .red
                case .stable: return .orange
                case .decreasing: return .green
                case .resolved: return .gray
                }
            }
        }
    }
    
    struct ReportingConfiguration {
        var autoReport = true
        var reportingThreshold: ErrorReport.ErrorInfo.Severity = .warning
        var includeDeviceInfo = true
        var includeNetworkInfo = true
        var includeStackTrace = true
        var maxBreadcrumbs = 50
        var deduplicationWindow = 300.0 // 5 minutes
        var enabledServices: Set<AnalyticsService> = [.crashlytics]
        var customEndpoint: String?
        var apiKey: String?
        var batchSize = 10
        var flushInterval = 60.0 // seconds
        
        // Privacy settings
        var anonymizeUserData = false
        var excludedDataKeys: Set<String> = []
        var sensitiveDataRegex: String?
    }
    
    struct ReportingStats {
        var totalReports = 0
        var successfulReports = 0
        var failedReports = 0
        var ignoredReports = 0
        var averageReportingTime: TimeInterval = 0
        var reportsByService: [AnalyticsService: Int] = [:]
        var reportsBySeverity: [ErrorReport.ErrorInfo.Severity: Int] = [:]
        
        var successRate: Double {
            guard totalReports > 0 else { return 0 }
            return Double(successfulReports) / Double(totalReports)
        }
    }
    
    init() {
        generateSampleData()
        startReportingTimer()
    }
    
    private func generateSampleData() {
        // Create sample error reports
        let errors = [
            ("Network timeout", ErrorReport.ErrorInfo.Severity.error, 408),
            ("Authentication failed", .error, 401),
            ("Rate limit exceeded", .warning, 429),
            ("Invalid request format", .error, 400),
            ("Server error", .fatal, 500),
            ("Cache miss", .info, nil),
            ("Stream interrupted", .warning, nil)
        ]
        
        for (message, severity, code) in errors {
            let errorInfo = ErrorReport.ErrorInfo(
                type: "DeepSeekError",
                message: message,
                code: code,
                stackTrace: generateStackTrace(),
                severity: severity
            )
            
            let context = generateContext()
            let metadata = generateMetadata(for: message)
            
            let report = ErrorReport(
                error: errorInfo,
                context: context,
                metadata: metadata,
                reportedTo: [],
                status: .pending
            )
            
            reports.append(report)
        }
        
        // Aggregate errors
        aggregateErrors()
        
        // Update stats
        updateStats()
    }
    
    private func generateStackTrace() -> [String] {
        return [
            "DeepSeekKit.DeepSeekClient.sendMessage(_:) (DeepSeekClient.swift:125)",
            "ChatViewModel.sendMessage() async (ChatViewModel.swift:87)",
            "ChatView.body.getter.closure #1 () async (ChatView.swift:45)",
            "_SwiftUI_AsyncButtonAction.performAction() async (SwiftUI:0)",
            "@main App.main() (App.swift:12)"
        ]
    }
    
    private func generateContext() -> ErrorReport.ErrorContext {
        let deviceInfo = ErrorReport.ErrorContext.DeviceInfo(
            model: "iPhone 15 Pro",
            osVersion: "iOS 17.2",
            appVersion: "1.0.0",
            buildNumber: "100",
            freeMemory: 2_147_483_648, // 2GB
            diskSpace: 10_737_418_240, // 10GB
            batteryLevel: 0.85,
            isJailbroken: false
        )
        
        let appState = ErrorReport.ErrorContext.AppState(
            viewHierarchy: "ContentView > ChatView > MessageList",
            memoryUsage: 134_217_728, // 128MB
            cpuUsage: 15.5,
            activeRequests: 2,
            sessionDuration: 1800, // 30 minutes
            lastAction: "sendMessage"
        )
        
        let networkInfo = ErrorReport.ErrorContext.NetworkInfo(
            connectionType: "WiFi",
            carrier: nil,
            signalStrength: -50,
            isReachable: true
        )
        
        return ErrorReport.ErrorContext(
            userId: "user_123",
            sessionId: UUID().uuidString,
            deviceInfo: deviceInfo,
            appState: appState,
            networkInfo: networkInfo,
            customData: ["theme": "dark", "locale": "en_US"]
        )
    }
    
    private func generateMetadata(for error: String) -> ErrorReport.ReportMetadata {
        let fingerprint = error.replacingOccurrences(of: " ", with: "_").lowercased()
        
        let breadcrumbs = [
            ErrorReport.ReportMetadata.Breadcrumb(
                timestamp: Date().addingTimeInterval(-60),
                category: "navigation",
                message: "User navigated to ChatView",
                level: "info",
                data: nil
            ),
            ErrorReport.ReportMetadata.Breadcrumb(
                timestamp: Date().addingTimeInterval(-30),
                category: "action",
                message: "User typed message",
                level: "info",
                data: ["length": 150]
            ),
            ErrorReport.ReportMetadata.Breadcrumb(
                timestamp: Date().addingTimeInterval(-5),
                category: "network",
                message: "API request started",
                level: "info",
                data: ["endpoint": "/chat/completions"]
            )
        ]
        
        return ErrorReport.ReportMetadata(
            fingerprint: fingerprint,
            tags: ["ios", "production", "deepseek-api"],
            breadcrumbs: breadcrumbs,
            attachments: []
        )
    }
    
    func reportError(
        _ error: Error,
        severity: ErrorReport.ErrorInfo.Severity = .error,
        context: [String: Any]? = nil
    ) async {
        guard reportingEnabled else { return }
        guard severity.rawValue >= configuration.reportingThreshold.rawValue else { return }
        
        isReporting = true
        
        // Create error report
        let errorInfo = ErrorReport.ErrorInfo(
            type: String(describing: type(of: error)),
            message: error.localizedDescription,
            code: (error as NSError).code,
            stackTrace: Thread.callStackSymbols,
            severity: severity
        )
        
        let reportContext = generateContext()
        let metadata = ErrorReport.ReportMetadata(
            fingerprint: generateFingerprint(for: error),
            tags: generateTags(for: error),
            breadcrumbs: collectBreadcrumbs(),
            attachments: []
        )
        
        var report = ErrorReport(
            error: errorInfo,
            context: reportContext,
            metadata: metadata
        )
        
        // Check for deduplication
        if isDuplicate(report) {
            report.status = .ignored
            stats.ignoredReports += 1
        } else {
            // Report to enabled services
            for service in configuration.enabledServices {
                await reportToService(report, service: service)
            }
        }
        
        reports.insert(report, at: 0)
        stats.totalReports += 1
        
        // Aggregate
        aggregateErrors()
        
        isReporting = false
    }
    
    private func reportToService(_ report: ErrorReport, service: AnalyticsService) async {
        // Simulate reporting to service
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // In real implementation, send to actual service
            if var updatedReport = reports.first(where: { $0.id == report.id }) {
                updatedReport.reportedTo.append(service)
                updatedReport.status = .reported
                
                if let index = reports.firstIndex(where: { $0.id == report.id }) {
                    reports[index] = updatedReport
                }
            }
            
            stats.successfulReports += 1
            stats.reportsByService[service, default: 0] += 1
            
        } catch {
            stats.failedReports += 1
            
            if var updatedReport = reports.first(where: { $0.id == report.id }) {
                updatedReport.status = .failed
                
                if let index = reports.firstIndex(where: { $0.id == report.id }) {
                    reports[index] = updatedReport
                }
            }
        }
    }
    
    private func generateFingerprint(for error: Error) -> String {
        let components = [
            String(describing: type(of: error)),
            error.localizedDescription,
            (error as NSError).domain,
            String((error as NSError).code)
        ]
        
        return components.joined(separator: "-")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }
    
    private func generateTags(for error: Error) -> [String] {
        var tags = ["ios", "deepseek-kit"]
        
        // Add error-specific tags
        if let deepSeekError = error as? DeepSeekError {
            switch deepSeekError {
            case .authenticationError:
                tags.append("auth")
            case .rateLimitExceeded:
                tags.append("rate-limit")
            case .networkError:
                tags.append("network")
            case .apiError:
                tags.append("api")
            default:
                tags.append("unknown")
            }
        }
        
        return tags
    }
    
    private func collectBreadcrumbs() -> [ErrorReport.ReportMetadata.Breadcrumb] {
        // In real implementation, maintain a circular buffer of breadcrumbs
        return []
    }
    
    private func isDuplicate(_ report: ErrorReport) -> Bool {
        let recentReports = reports.filter {
            $0.timestamp.timeIntervalSinceNow > -configuration.deduplicationWindow
        }
        
        return recentReports.contains { existing in
            existing.metadata.fingerprint == report.metadata.fingerprint
        }
    }
    
    private func aggregateErrors() {
        var aggregated: [String: AggregatedError] = [:]
        
        for report in reports {
            let fingerprint = report.metadata.fingerprint
            
            if var existing = aggregated[fingerprint] {
                existing.occurrences += 1
                existing.lastSeen = max(existing.lastSeen, report.timestamp)
                if let userId = report.context.userId {
                    existing.affectedUsers.insert(userId)
                }
                aggregated[fingerprint] = existing
            } else {
                let newAggregate = AggregatedError(
                    fingerprint: fingerprint,
                    firstSeen: report.timestamp,
                    lastSeen: report.timestamp,
                    occurrences: 1,
                    affectedUsers: Set([report.context.userId].compactMap { $0 }),
                    errorType: report.error.type,
                    errorMessage: report.error.message,
                    trend: .stable
                )
                aggregated[fingerprint] = newAggregate
            }
        }
        
        // Calculate trends
        for (fingerprint, var error) in aggregated {
            error.trend = calculateTrend(for: fingerprint)
            aggregated[fingerprint] = error
        }
        
        aggregatedErrors = Array(aggregated.values)
            .sorted { $0.lastSeen > $1.lastSeen }
    }
    
    private func calculateTrend(for fingerprint: String) -> AggregatedError.Trend {
        let recentReports = reports.filter {
            $0.metadata.fingerprint == fingerprint &&
            $0.timestamp.timeIntervalSinceNow > -3600 // Last hour
        }
        
        let olderReports = reports.filter {
            $0.metadata.fingerprint == fingerprint &&
            $0.timestamp.timeIntervalSinceNow > -7200 && // 2 hours ago
            $0.timestamp.timeIntervalSinceNow <= -3600 // to 1 hour ago
        }
        
        if recentReports.isEmpty && !olderReports.isEmpty {
            return .resolved
        } else if recentReports.count > olderReports.count * 2 {
            return .increasing
        } else if recentReports.count < olderReports.count / 2 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func updateStats() {
        stats.reportsBySeverity = Dictionary(
            grouping: reports,
            by: { $0.error.severity }
        ).mapValues { $0.count }
    }
    
    private func startReportingTimer() {
        Timer.scheduledTimer(withTimeInterval: configuration.flushInterval, repeats: true) { _ in
            Task {
                await self.flushPendingReports()
            }
        }
    }
    
    private func flushPendingReports() async {
        let pendingReports = reports.filter { $0.status == .pending }
        
        for report in pendingReports.prefix(configuration.batchSize) {
            for service in configuration.enabledServices {
                await reportToService(report, service: service)
            }
        }
    }
}

// UI Components
struct ReportingOverview: View {
    @ObservedObject var reporter: ErrorReporter
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error Reporting")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(reporter.reportingEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(reporter.reportingEnabled ? "Active" : "Disabled")
                            .font(.subheadline)
                            .foregroundColor(reporter.reportingEnabled ? .green : .gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(reporter.reports.count)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Total Reports")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Success rate
            VStack(spacing: 8) {
                HStack {
                    Text("Success Rate")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.1f%%", reporter.stats.successRate * 100))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: reporter.stats.successRate)
                    .tint(successRateColor)
            }
            
            // Report breakdown
            HStack(spacing: 16) {
                ReportStatCard(
                    title: "Successful",
                    count: reporter.stats.successfulReports,
                    color: .green
                )
                
                ReportStatCard(
                    title: "Failed",
                    count: reporter.stats.failedReports,
                    color: .red
                )
                
                ReportStatCard(
                    title: "Ignored",
                    count: reporter.stats.ignoredReports,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var successRateColor: Color {
        if reporter.stats.successRate > 0.9 {
            return .green
        } else if reporter.stats.successRate > 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

struct ReportStatCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AnalyticsServicesView: View {
    @ObservedObject var reporter: ErrorReporter
    @Binding var selectedService: AnalyticsService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics Services")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnalyticsService.allCases, id: \.self) { service in
                        ServiceCard(
                            service: service,
                            isEnabled: reporter.configuration.enabledServices.contains(service),
                            reportCount: reporter.stats.reportsByService[service] ?? 0,
                            isSelected: selectedService == service,
                            action: {
                                selectedService = service
                                
                                if reporter.configuration.enabledServices.contains(service) {
                                    reporter.configuration.enabledServices.remove(service)
                                } else {
                                    reporter.configuration.enabledServices.insert(service)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ServiceCard: View {
    let service: AnalyticsService
    let isEnabled: Bool
    let reportCount: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(service.color.opacity(isEnabled ? 0.2 : 0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: service.icon)
                        .font(.title)
                        .foregroundColor(isEnabled ? service.color : .gray)
                }
                
                Text(service.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 80)
                
                if isEnabled {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        if reportCount > 0 {
                            Text("\(reportCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.gray.opacity(0.1) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? service.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ErrorAggregationView: View {
    @ObservedObject var reporter: ErrorReporter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Error Trends")
                .font(.headline)
            
            if reporter.aggregatedErrors.isEmpty {
                Text("No errors to aggregate")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(reporter.aggregatedErrors.prefix(5)) { error in
                    AggregatedErrorRow(error: error)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct AggregatedErrorRow: View {
    let error: ErrorReporter.AggregatedError
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: error.trend.icon)
                    .foregroundColor(error.trend.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.errorType)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(error.errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(error.occurrences)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("occurrences")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                HStack(spacing: 20) {
                    Label("\(error.affectedUsers.count) users", systemImage: "person.2")
                    Label("First: \(error.firstSeen, style: .relative)", systemImage: "clock")
                    Label("Last: \(error.lastSeen, style: .relative)", systemImage: "clock.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct RecentReportsView: View {
    @ObservedObject var reporter: ErrorReporter
    @Binding var showDetails: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Reports")
                    .font(.headline)
                
                Spacer()
                
                Button(showDetails ? "Hide Details" : "Show Details") {
                    showDetails.toggle()
                }
                .font(.caption)
            }
            
            if reporter.reports.isEmpty {
                Text("No reports yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(reporter.reports.prefix(10)) { report in
                    ReportRow(report: report, showDetails: showDetails)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ReportRow: View {
    let report: ErrorReporter.ErrorReport
    let showDetails: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: report.error.severity.icon)
                    .foregroundColor(report.error.severity.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.error.message)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    HStack {
                        Text(report.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let code = report.error.code {
                            Text("• Code: \(code)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                ReportStatusBadge(status: report.status)
            }
            
            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    // Services
                    if !report.reportedTo.isEmpty {
                        HStack {
                            Text("Reported to:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                ForEach(report.reportedTo, id: \.self) { service in
                                    Image(systemName: service.icon)
                                        .font(.caption)
                                        .foregroundColor(service.color)
                                }
                            }
                        }
                    }
                    
                    // Tags
                    if !report.metadata.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(report.metadata.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReportStatusBadge: View {
    let status: ErrorReporter.ErrorReport.ReportStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .cornerRadius(6)
    }
}

struct ReportingConfigurationView: View {
    @ObservedObject var reporter: ErrorReporter
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Configuration")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Auto-report errors", isOn: $reporter.configuration.autoReport)
                    
                    Toggle("Include device info", isOn: $reporter.configuration.includeDeviceInfo)
                    
                    Toggle("Include network info", isOn: $reporter.configuration.includeNetworkInfo)
                    
                    Toggle("Include stack trace", isOn: $reporter.configuration.includeStackTrace)
                    
                    Toggle("Anonymize user data", isOn: $reporter.configuration.anonymizeUserData)
                    
                    // Threshold picker
                    HStack {
                        Text("Reporting threshold:")
                        Picker("", selection: $reporter.configuration.reportingThreshold) {
                            ForEach(ErrorReporter.ErrorReport.ErrorInfo.Severity.allCases, id: \.self) { severity in
                                Label(severity.rawValue, systemImage: severity.icon)
                                    .tag(severity)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Batch settings
                    HStack {
                        Text("Batch size:")
                        Stepper("\(reporter.configuration.batchSize)", value: $reporter.configuration.batchSize, in: 1...50)
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct TestReportingView: View {
    @ObservedObject var reporter: ErrorReporter
    let service: AnalyticsService
    @State private var selectedSeverity: ErrorReporter.ErrorReport.ErrorInfo.Severity = .error
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Reporting")
                .font(.headline)
            
            Picker("Severity", selection: $selectedSeverity) {
                ForEach(ErrorReporter.ErrorReport.ErrorInfo.Severity.allCases, id: \.self) { severity in
                    Text(severity.rawValue).tag(severity)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            HStack {
                Button("Generate Test Error") {
                    Task {
                        let error = NSError(
                            domain: "TestDomain",
                            code: 999,
                            userInfo: [NSLocalizedDescriptionKey: "Test error for \(service.rawValue)"]
                        )
                        
                        await reporter.reportError(
                            error,
                            severity: selectedSeverity,
                            context: ["test": true, "service": service.rawValue]
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(reporter.isReporting)
                
                if reporter.isReporting {
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