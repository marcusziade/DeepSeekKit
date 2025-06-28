import SwiftUI
import DeepSeekKit

// Tracking error patterns and frequency
struct ErrorPatternsView: View {
    @StateObject private var patternAnalyzer = ErrorPatternAnalyzer()
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var showRecommendations = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Error Pattern Analysis")
                    .font(.largeTitle)
                    .bold()
                
                // Time range selector
                TimeRangeSelector(selectedRange: $selectedTimeRange)
                
                // Pattern overview
                PatternOverviewCard(
                    analyzer: patternAnalyzer,
                    timeRange: selectedTimeRange
                )
                
                // Error trends chart
                ErrorTrendsChart(
                    analyzer: patternAnalyzer,
                    timeRange: selectedTimeRange
                )
                
                // Most common errors
                CommonErrorsList(
                    analyzer: patternAnalyzer,
                    timeRange: selectedTimeRange
                )
                
                // Error correlations
                ErrorCorrelationsView(analyzer: patternAnalyzer)
                
                // Pattern insights
                if showRecommendations {
                    PatternInsightsView(analyzer: patternAnalyzer)
                }
                
                // Actions
                PatternActionsView(
                    analyzer: patternAnalyzer,
                    showRecommendations: $showRecommendations
                )
            }
            .padding()
        }
        .onAppear {
            patternAnalyzer.analyzePatterns()
        }
    }
}

// Time ranges for analysis
enum TimeRange: String, CaseIterable {
    case lastHour = "Last Hour"
    case last24Hours = "Last 24 Hours"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case allTime = "All Time"
    
    var seconds: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last24Hours: return 86400
        case .last7Days: return 604800
        case .last30Days: return 2592000
        case .allTime: return .infinity
        }
    }
}

// Error pattern analyzer
@MainActor
class ErrorPatternAnalyzer: ObservableObject {
    @Published var errorEvents: [ErrorEvent] = []
    @Published var patterns: [ErrorPattern] = []
    @Published var insights: [PatternInsight] = []
    @Published var isAnalyzing = false
    
    private let client = DeepSeekClient()
    
    struct ErrorEvent: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let error: ErrorType
        let context: ErrorContext
        let duration: TimeInterval?
        let resolved: Bool
        
        enum ErrorType: String, CaseIterable {
            case authentication = "Authentication"
            case rateLimit = "Rate Limit"
            case network = "Network"
            case timeout = "Timeout"
            case serverError = "Server Error"
            case invalidRequest = "Invalid Request"
            
            var color: Color {
                switch self {
                case .authentication: return .red
                case .rateLimit: return .orange
                case .network: return .blue
                case .timeout: return .purple
                case .serverError: return .pink
                case .invalidRequest: return .yellow
                }
            }
        }
        
        struct ErrorContext {
            let endpoint: String?
            let model: String?
            let userAction: String?
            let networkType: String?
            let appVersion: String
        }
    }
    
    struct ErrorPattern: Identifiable {
        let id = UUID()
        let type: PatternType
        let frequency: Int
        let timeDistribution: TimeDistribution
        let severity: Severity
        let correlations: [Correlation]
        
        enum PatternType {
            case recurring(error: ErrorEvent.ErrorType, interval: TimeInterval)
            case burst(errors: [ErrorEvent.ErrorType], window: TimeInterval)
            case sequential(chain: [ErrorEvent.ErrorType])
            case conditional(trigger: String, result: ErrorEvent.ErrorType)
            
            var description: String {
                switch self {
                case .recurring(let error, let interval):
                    return "\(error.rawValue) recurring every \(formatInterval(interval))"
                case .burst(let errors, let window):
                    return "\(errors.count) errors within \(formatInterval(window))"
                case .sequential(let chain):
                    return "Sequential: \(chain.map { $0.rawValue }.joined(separator: " → "))"
                case .conditional(let trigger, let result):
                    return "When \(trigger) then \(result.rawValue)"
                }
            }
            
            private func formatInterval(_ interval: TimeInterval) -> String {
                if interval < 60 {
                    return "\(Int(interval))s"
                } else if interval < 3600 {
                    return "\(Int(interval / 60))m"
                } else if interval < 86400 {
                    return "\(Int(interval / 3600))h"
                } else {
                    return "\(Int(interval / 86400))d"
                }
            }
        }
        
        struct TimeDistribution {
            let hourlyDistribution: [Int] // 24 hours
            let dailyDistribution: [Int] // 7 days
            let peakHours: [Int]
            let quietHours: [Int]
        }
        
        enum Severity: String {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"
            
            var color: Color {
                switch self {
                case .low: return .green
                case .medium: return .yellow
                case .high: return .orange
                case .critical: return .red
                }
            }
        }
        
        struct Correlation {
            let factor: String
            let strength: Double // 0.0 to 1.0
            let description: String
        }
    }
    
    struct PatternInsight: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let recommendation: String
        let priority: Priority
        let estimatedImpact: Impact
        
        enum Priority: String {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case urgent = "Urgent"
            
            var color: Color {
                switch self {
                case .low: return .gray
                case .medium: return .blue
                case .high: return .orange
                case .urgent: return .red
                }
            }
        }
        
        struct Impact {
            let errorReduction: Double // Percentage
            let performanceImprovement: Double // Percentage
            let userExperienceScore: Double // 0-10
        }
    }
    
    init() {
        generateSampleData()
    }
    
    private func generateSampleData() {
        // Generate sample error events
        let errorTypes = ErrorEvent.ErrorType.allCases
        let now = Date()
        
        for i in 0..<500 {
            let hoursAgo = Double.random(in: 0...720) // Last 30 days
            let timestamp = now.addingTimeInterval(-hoursAgo * 3600)
            
            let errorType = errorTypes.randomElement()!
            let context = ErrorEvent.ErrorContext(
                endpoint: ["/chat/completions", "/models", "/usage"].randomElement(),
                model: ["deepseek-chat", "deepseek-coder"].randomElement(),
                userAction: ["sendMessage", "streamMessage", "getModels"].randomElement(),
                networkType: ["WiFi", "Cellular", "Ethernet"].randomElement(),
                appVersion: "1.0.0"
            )
            
            let event = ErrorEvent(
                timestamp: timestamp,
                error: errorType,
                context: context,
                duration: Double.random(in: 0.1...30),
                resolved: Bool.random()
            )
            
            errorEvents.append(event)
        }
        
        // Sort by timestamp
        errorEvents.sort { $0.timestamp > $1.timestamp }
    }
    
    func analyzePatterns() {
        isAnalyzing = true
        patterns.removeAll()
        insights.removeAll()
        
        // Analyze recurring patterns
        analyzeRecurringPatterns()
        
        // Analyze burst patterns
        analyzeBurstPatterns()
        
        // Analyze sequential patterns
        analyzeSequentialPatterns()
        
        // Generate insights
        generateInsights()
        
        isAnalyzing = false
    }
    
    private func analyzeRecurringPatterns() {
        // Group errors by type
        let groupedErrors = Dictionary(grouping: errorEvents) { $0.error }
        
        for (errorType, events) in groupedErrors {
            guard events.count > 5 else { continue }
            
            // Calculate intervals
            var intervals: [TimeInterval] = []
            for i in 1..<events.count {
                let interval = events[i-1].timestamp.timeIntervalSince(events[i].timestamp)
                intervals.append(interval)
            }
            
            // Find recurring interval
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let variance = intervals.map { pow($0 - averageInterval, 2) }.reduce(0, +) / Double(intervals.count)
            
            if sqrt(variance) < averageInterval * 0.3 { // Low variance indicates pattern
                let pattern = ErrorPattern(
                    type: .recurring(error: errorType, interval: averageInterval),
                    frequency: events.count,
                    timeDistribution: calculateTimeDistribution(for: events),
                    severity: calculateSeverity(for: errorType, frequency: events.count),
                    correlations: findCorrelations(for: events)
                )
                patterns.append(pattern)
            }
        }
    }
    
    private func analyzeBurstPatterns() {
        let windows: [TimeInterval] = [300, 3600, 86400] // 5 min, 1 hour, 1 day
        
        for window in windows {
            var i = 0
            while i < errorEvents.count {
                var burst: [ErrorEvent] = [errorEvents[i]]
                var j = i + 1
                
                while j < errorEvents.count &&
                      errorEvents[i].timestamp.timeIntervalSince(errorEvents[j].timestamp) < window {
                    burst.append(errorEvents[j])
                    j += 1
                }
                
                if burst.count >= 5 {
                    let errorTypes = Array(Set(burst.map { $0.error }))
                    let pattern = ErrorPattern(
                        type: .burst(errors: errorTypes, window: window),
                        frequency: burst.count,
                        timeDistribution: calculateTimeDistribution(for: burst),
                        severity: .high,
                        correlations: findCorrelations(for: burst)
                    )
                    patterns.append(pattern)
                    i = j
                } else {
                    i += 1
                }
            }
        }
    }
    
    private func analyzeSequentialPatterns() {
        // Look for common error sequences
        var sequences: [[ErrorEvent.ErrorType]] = []
        
        for i in 0..<(errorEvents.count - 2) {
            let sequence = [
                errorEvents[i].error,
                errorEvents[i+1].error,
                errorEvents[i+2].error
            ]
            
            // Check if this sequence appears multiple times
            var count = 0
            for j in 0..<(errorEvents.count - 2) {
                if errorEvents[j].error == sequence[0] &&
                   errorEvents[j+1].error == sequence[1] &&
                   errorEvents[j+2].error == sequence[2] {
                    count += 1
                }
            }
            
            if count >= 3 && !sequences.contains(sequence) {
                sequences.append(sequence)
                
                let pattern = ErrorPattern(
                    type: .sequential(chain: sequence),
                    frequency: count,
                    timeDistribution: calculateTimeDistribution(for: errorEvents),
                    severity: .medium,
                    correlations: []
                )
                patterns.append(pattern)
            }
        }
    }
    
    private func calculateTimeDistribution(for events: [ErrorEvent]) -> ErrorPattern.TimeDistribution {
        var hourly = Array(repeating: 0, count: 24)
        var daily = Array(repeating: 0, count: 7)
        
        for event in events {
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            let weekday = Calendar.current.component(.weekday, from: event.timestamp) - 1
            
            hourly[hour] += 1
            daily[weekday] += 1
        }
        
        let peakHours = hourly.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(3)
            .map { $0.offset }
        
        let quietHours = hourly.enumerated()
            .sorted { $0.element < $1.element }
            .prefix(3)
            .map { $0.offset }
        
        return ErrorPattern.TimeDistribution(
            hourlyDistribution: hourly,
            dailyDistribution: daily,
            peakHours: Array(peakHours),
            quietHours: Array(quietHours)
        )
    }
    
    private func calculateSeverity(for errorType: ErrorEvent.ErrorType, frequency: Int) -> ErrorPattern.Severity {
        let impactScore = getImpactScore(for: errorType)
        let frequencyScore = min(Double(frequency) / 100.0, 1.0)
        
        let totalScore = (impactScore + frequencyScore) / 2
        
        if totalScore > 0.75 {
            return .critical
        } else if totalScore > 0.5 {
            return .high
        } else if totalScore > 0.25 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func getImpactScore(for errorType: ErrorEvent.ErrorType) -> Double {
        switch errorType {
        case .authentication: return 1.0
        case .serverError: return 0.9
        case .rateLimit: return 0.7
        case .timeout: return 0.6
        case .network: return 0.5
        case .invalidRequest: return 0.3
        }
    }
    
    private func findCorrelations(for events: [ErrorEvent]) -> [ErrorPattern.Correlation] {
        var correlations: [ErrorPattern.Correlation] = []
        
        // Time of day correlation
        let hourCounts = Dictionary(grouping: events) {
            Calendar.current.component(.hour, from: $0.timestamp)
        }
        
        if let peakHour = hourCounts.max(by: { $0.value.count < $1.value.count }) {
            let strength = Double(peakHour.value.count) / Double(events.count)
            if strength > 0.3 {
                correlations.append(ErrorPattern.Correlation(
                    factor: "Time of Day",
                    strength: strength,
                    description: "Most errors occur at \(peakHour.key):00"
                ))
            }
        }
        
        // Network type correlation
        let networkCounts = Dictionary(grouping: events) { $0.context.networkType ?? "Unknown" }
        
        if let problemNetwork = networkCounts.max(by: { $0.value.count < $1.value.count }) {
            let strength = Double(problemNetwork.value.count) / Double(events.count)
            if strength > 0.5 {
                correlations.append(ErrorPattern.Correlation(
                    factor: "Network Type",
                    strength: strength,
                    description: "\(Int(strength * 100))% occur on \(problemNetwork.key)"
                ))
            }
        }
        
        return correlations
    }
    
    private func generateInsights() {
        // Rate limit insight
        if let rateLimitPattern = patterns.first(where: { 
            if case .recurring(let error, _) = $0.type, error == .rateLimit { return true }
            return false
        }) {
            insights.append(PatternInsight(
                title: "Optimize Rate Limit Usage",
                description: "Rate limit errors occur \(rateLimitPattern.frequency) times with predictable pattern",
                recommendation: "Implement request batching and caching to reduce API calls by 40%",
                priority: .high,
                estimatedImpact: PatternInsight.Impact(
                    errorReduction: 0.4,
                    performanceImprovement: 0.2,
                    userExperienceScore: 8.5
                )
            ))
        }
        
        // Network error insight
        let networkErrors = errorEvents.filter { $0.error == .network }
        if networkErrors.count > 50 {
            insights.append(PatternInsight(
                title: "Improve Network Resilience",
                description: "Network errors account for \(networkErrors.count) failures",
                recommendation: "Implement offline mode and automatic retry with exponential backoff",
                priority: .urgent,
                estimatedImpact: PatternInsight.Impact(
                    errorReduction: 0.6,
                    performanceImprovement: 0.3,
                    userExperienceScore: 9.0
                )
            ))
        }
        
        // Peak hour insight
        if let burstPattern = patterns.first(where: {
            if case .burst = $0.type { return true }
            return false
        }) {
            let peakHours = burstPattern.timeDistribution.peakHours
            insights.append(PatternInsight(
                title: "Scale for Peak Hours",
                description: "Error bursts occur during hours: \(peakHours.map { "\($0):00" }.joined(separator: ", "))",
                recommendation: "Pre-scale resources or implement request queuing during peak times",
                priority: .medium,
                estimatedImpact: PatternInsight.Impact(
                    errorReduction: 0.3,
                    performanceImprovement: 0.5,
                    userExperienceScore: 7.5
                )
            ))
        }
    }
    
    func getErrorCounts(for timeRange: TimeRange) -> [ErrorEvent.ErrorType: Int] {
        let startDate = Date().addingTimeInterval(-timeRange.seconds)
        let filteredEvents = errorEvents.filter { $0.timestamp > startDate }
        
        return Dictionary(grouping: filteredEvents) { $0.error }
            .mapValues { $0.count }
    }
    
    func getHourlyTrend(for timeRange: TimeRange) -> [(hour: Int, count: Int)] {
        let startDate = Date().addingTimeInterval(-timeRange.seconds)
        let filteredEvents = errorEvents.filter { $0.timestamp > startDate }
        
        let hourCounts = Dictionary(grouping: filteredEvents) {
            Calendar.current.component(.hour, from: $0.timestamp)
        }
        
        return (0..<24).map { hour in
            (hour: hour, count: hourCounts[hour]?.count ?? 0)
        }
    }
}

// UI Components
struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PatternOverviewCard: View {
    @ObservedObject var analyzer: ErrorPatternAnalyzer
    let timeRange: TimeRange
    
    var body: some View {
        let errorCounts = analyzer.getErrorCounts(for: timeRange)
        let totalErrors = errorCounts.values.reduce(0, +)
        
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Error Patterns")
                        .font(.headline)
                    Text("\(analyzer.patterns.count) patterns detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(totalErrors)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Total Errors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Error type breakdown
            HStack(spacing: 12) {
                ForEach(ErrorEvent.ErrorType.allCases, id: \.self) { errorType in
                    if let count = errorCounts[errorType], count > 0 {
                        VStack {
                            Text("\(count)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(errorType.color)
                            Text(errorType.rawValue)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ErrorTrendsChart: View {
    @ObservedObject var analyzer: ErrorPatternAnalyzer
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly Error Distribution")
                .font(.headline)
            
            let hourlyData = analyzer.getHourlyTrend(for: timeRange)
            let maxCount = hourlyData.map { $0.count }.max() ?? 1
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(hourlyData, id: \.hour) { data in
                    VStack {
                        Spacer()
                        
                        Rectangle()
                            .fill(barColor(for: data.hour))
                            .frame(height: barHeight(count: data.count, max: maxCount))
                        
                        Text("\(data.hour)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150)
            
            // Legend
            HStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                Text("Peak hours")
                    .font(.caption)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("Normal hours")
                    .font(.caption)
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Quiet hours")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    func barHeight(count: Int, max: Int) -> CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(count) / CGFloat(max) * 120
    }
    
    func barColor(for hour: Int) -> Color {
        let workingHours = 9...17
        let peakHours = [10, 11, 14, 15, 16]
        
        if peakHours.contains(hour) {
            return .orange
        } else if workingHours.contains(hour) {
            return .blue
        } else {
            return .green
        }
    }
}

struct CommonErrorsList: View {
    @ObservedObject var analyzer: ErrorPatternAnalyzer
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most Common Errors")
                .font(.headline)
            
            let errorCounts = analyzer.getErrorCounts(for: timeRange)
            let sortedErrors = errorCounts.sorted { $0.value > $1.value }.prefix(5)
            
            ForEach(sortedErrors, id: \.key) { errorType, count in
                CommonErrorRow(
                    errorType: errorType,
                    count: count,
                    total: errorCounts.values.reduce(0, +)
                )
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct CommonErrorRow: View {
    let errorType: ErrorPatternAnalyzer.ErrorEvent.ErrorType
    let count: Int
    let total: Int
    
    var body: some View {
        HStack {
            Circle()
                .fill(errorType.color)
                .frame(width: 8, height: 8)
            
            Text(errorType.rawValue)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("(\(percentage)%)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(errorType.color)
                        .frame(width: geometry.size.width * CGFloat(count) / CGFloat(total), height: 4)
                }
                .cornerRadius(2)
            }
            .frame(width: 100, height: 4)
        }
    }
    
    var percentage: Int {
        guard total > 0 else { return 0 }
        return Int(Double(count) / Double(total) * 100)
    }
}

struct ErrorCorrelationsView: View {
    @ObservedObject var analyzer: ErrorPatternAnalyzer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Correlations")
                .font(.headline)
            
            if analyzer.patterns.isEmpty {
                Text("No patterns detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(analyzer.patterns.prefix(3)) { pattern in
                    PatternCard(pattern: pattern)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct PatternCard: View {
    let pattern: ErrorPatternAnalyzer.ErrorPattern
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(pattern.type.description, systemImage: patternIcon)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Spacer()
                
                SeverityBadge(severity: pattern.severity)
            }
            
            HStack {
                Label("\(pattern.frequency) occurrences", systemImage: "number.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !pattern.correlations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Correlations:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(pattern.correlations, id: \.factor) { correlation in
                        HStack {
                            Text(correlation.factor)
                                .font(.caption2)
                            
                            ProgressView(value: correlation.strength)
                                .frame(width: 50)
                            
                            Text("\(Int(correlation.strength * 100))%")
                                .font(.caption2)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    var patternIcon: String {
        switch pattern.type {
        case .recurring: return "arrow.clockwise"
        case .burst: return "burst"
        case .sequential: return "arrow.right.arrow.left"
        case .conditional: return "arrow.triangle.branch"
        }
    }
}

struct SeverityBadge: View {
    let severity: ErrorPatternAnalyzer.ErrorPattern.Severity
    
    var body: some View {
        Text(severity.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severity.color)
            .cornerRadius(6)
    }
}

struct PatternInsightsView: View {
    @ObservedObject var analyzer: ErrorPatternAnalyzer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pattern Insights & Recommendations")
                .font(.headline)
            
            if analyzer.insights.isEmpty {
                Text("Analyzing patterns...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(analyzer.insights) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

struct InsightCard: View {
    let insight: ErrorPatternAnalyzer.PatternInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(insight.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        PriorityBadge(priority: insight.priority)
                    }
                    
                    Text(insight.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Label(insight.recommendation, systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 20) {
                        ImpactMetric(
                            label: "Error Reduction",
                            value: "\(Int(insight.estimatedImpact.errorReduction * 100))%",
                            icon: "arrow.down.circle"
                        )
                        
                        ImpactMetric(
                            label: "Performance",
                            value: "+\(Int(insight.estimatedImpact.performanceImprovement * 100))%",
                            icon: "speedometer"
                        )
                        
                        ImpactMetric(
                            label: "UX Score",
                            value: String(format: "%.1f", insight.estimatedImpact.userExperienceScore),
                            icon: "star.fill"
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct PriorityBadge: View {
    let priority: ErrorPatternAnalyzer.PatternInsight.Priority
    
    var body: some View {
        Text(priority.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priority.color)
            .cornerRadius(4)
    }
}

struct ImpactMetric: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.green)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PatternActionsView: View {
    @ObservedObject var analyzer: ErrorPatternAnalyzer
    @Binding var showRecommendations: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button("Analyze Patterns") {
                analyzer.analyzePatterns()
            }
            .buttonStyle(.borderedProminent)
            .disabled(analyzer.isAnalyzing)
            
            Button(showRecommendations ? "Hide Insights" : "Show Insights") {
                showRecommendations.toggle()
            }
            .buttonStyle(.bordered)
            
            if analyzer.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}