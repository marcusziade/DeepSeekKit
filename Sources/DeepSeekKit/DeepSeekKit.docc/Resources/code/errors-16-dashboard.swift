import SwiftUI
import DeepSeekKit
import Charts

// Error dashboard view with comprehensive analytics
struct ErrorDashboardView: View {
    @StateObject private var dashboard = ErrorDashboard()
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var selectedMetric: MetricType = .errorRate
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                DashboardHeaderView(
                    dashboard: dashboard,
                    selectedTimeRange: $selectedTimeRange
                )
                
                // Key metrics
                KeyMetricsView(dashboard: dashboard)
                
                // Error trends chart
                ErrorTrendsChartView(
                    dashboard: dashboard,
                    timeRange: selectedTimeRange,
                    selectedMetric: $selectedMetric
                )
                
                // Error distribution
                ErrorDistributionView(
                    dashboard: dashboard,
                    timeRange: selectedTimeRange
                )
                
                // Health indicators
                HealthIndicatorsView(dashboard: dashboard)
                
                // Top issues
                TopIssuesView(
                    dashboard: dashboard,
                    timeRange: selectedTimeRange
                )
                
                // Performance impact
                PerformanceImpactView(dashboard: dashboard)
                
                // Recommendations
                RecommendationsView(dashboard: dashboard)
            }
            .padding()
        }
        .onAppear {
            dashboard.refresh(for: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { newRange in
            dashboard.refresh(for: newRange)
        }
    }
}

// Time range options
enum TimeRange: String, CaseIterable {
    case last15Minutes = "15 min"
    case lastHour = "1 hour"
    case last24Hours = "24 hours"
    case last7Days = "7 days"
    case last30Days = "30 days"
    
    var seconds: TimeInterval {
        switch self {
        case .last15Minutes: return 900
        case .lastHour: return 3600
        case .last24Hours: return 86400
        case .last7Days: return 604800
        case .last30Days: return 2592000
        }
    }
}

// Metric types
enum MetricType: String, CaseIterable {
    case errorRate = "Error Rate"
    case responseTime = "Response Time"
    case availability = "Availability"
    case throughput = "Throughput"
    
    var unit: String {
        switch self {
        case .errorRate: return "%"
        case .responseTime: return "ms"
        case .availability: return "%"
        case .throughput: return "req/s"
        }
    }
    
    var color: Color {
        switch self {
        case .errorRate: return .red
        case .responseTime: return .orange
        case .availability: return .green
        case .throughput: return .blue
        }
    }
}

// Error dashboard manager
@MainActor
class ErrorDashboard: ObservableObject {
    @Published var metrics = DashboardMetrics()
    @Published var errorData: [ErrorDataPoint] = []
    @Published var errorDistribution: [ErrorCategory] = []
    @Published var healthScore: HealthScore = .good
    @Published var topIssues: [Issue] = []
    @Published var recommendations: [Recommendation] = []
    @Published var isRefreshing = false
    
    private let client = DeepSeekClient()
    
    struct DashboardMetrics {
        var totalRequests = 0
        var failedRequests = 0
        var averageResponseTime: TimeInterval = 0
        var availability = 0.0
        var errorRate = 0.0
        var throughput = 0.0
        
        // Trends (compared to previous period)
        var errorRateTrend: Trend = .stable
        var responseTimeTrend: Trend = .stable
        var availabilityTrend: Trend = .stable
        var throughputTrend: Trend = .stable
        
        enum Trend {
            case improving(Double) // percentage
            case stable
            case degrading(Double) // percentage
            
            var icon: String {
                switch self {
                case .improving: return "arrow.down.circle.fill"
                case .stable: return "equal.circle.fill"
                case .degrading: return "arrow.up.circle.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .improving: return .green
                case .stable: return .blue
                case .degrading: return .red
                }
            }
            
            var description: String {
                switch self {
                case .improving(let percentage):
                    return String(format: "↓ %.1f%%", percentage)
                case .stable:
                    return "Stable"
                case .degrading(let percentage):
                    return String(format: "↑ %.1f%%", percentage)
                }
            }
        }
    }
    
    struct ErrorDataPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let errorRate: Double
        let responseTime: Double
        let availability: Double
        let throughput: Double
        let errorCount: Int
        let successCount: Int
    }
    
    struct ErrorCategory: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
        let percentage: Double
        let icon: String
        let color: Color
        let severity: Severity
        
        enum Severity: Int {
            case low = 1
            case medium = 2
            case high = 3
            case critical = 4
        }
    }
    
    enum HealthScore: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case critical = "Critical"
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .yellow
            case .poor: return .orange
            case .critical: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .excellent: return "checkmark.shield.fill"
            case .good: return "checkmark.circle.fill"
            case .fair: return "exclamationmark.triangle.fill"
            case .poor: return "exclamationmark.octagon.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
        
        var score: Int {
            switch self {
            case .excellent: return 90
            case .good: return 75
            case .fair: return 60
            case .poor: return 40
            case .critical: return 20
            }
        }
    }
    
    struct Issue: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let impact: Impact
        let affectedUsers: Int
        let occurrences: Int
        let firstSeen: Date
        let lastSeen: Date
        let status: Status
        
        enum Impact: String {
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
        
        enum Status: String {
            case active = "Active"
            case investigating = "Investigating"
            case resolved = "Resolved"
            case monitoring = "Monitoring"
            
            var color: Color {
                switch self {
                case .active: return .red
                case .investigating: return .orange
                case .resolved: return .green
                case .monitoring: return .blue
                }
            }
        }
    }
    
    struct Recommendation: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let impact: String
        let effort: Effort
        let category: Category
        let priority: Priority
        
        enum Effort: String {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            
            var color: Color {
                switch self {
                case .low: return .green
                case .medium: return .orange
                case .high: return .red
                }
            }
        }
        
        enum Category: String {
            case performance = "Performance"
            case reliability = "Reliability"
            case scalability = "Scalability"
            case security = "Security"
            
            var icon: String {
                switch self {
                case .performance: return "speedometer"
                case .reliability: return "shield.checkerboard"
                case .scalability: return "arrow.up.arrow.down"
                case .security: return "lock.shield"
                }
            }
        }
        
        enum Priority: Int {
            case low = 1
            case medium = 2
            case high = 3
            case urgent = 4
            
            var color: Color {
                switch self {
                case .low: return .gray
                case .medium: return .blue
                case .high: return .orange
                case .urgent: return .red
                }
            }
            
            var label: String {
                switch self {
                case .low: return "Low"
                case .medium: return "Medium"
                case .high: return "High"
                case .urgent: return "Urgent"
                }
            }
        }
    }
    
    init() {
        generateSampleData()
    }
    
    func refresh(for timeRange: TimeRange) {
        isRefreshing = true
        
        Task {
            // Simulate data refresh
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            generateDataForTimeRange(timeRange)
            calculateMetrics(for: timeRange)
            analyzeHealth()
            identifyTopIssues()
            generateRecommendations()
            
            isRefreshing = false
        }
    }
    
    private func generateSampleData() {
        // Generate initial dashboard data
        generateDataForTimeRange(.last24Hours)
        calculateMetrics(for: .last24Hours)
        analyzeHealth()
        identifyTopIssues()
        generateRecommendations()
    }
    
    private func generateDataForTimeRange(_ timeRange: TimeRange) {
        let dataPoints = Int(timeRange.seconds / 3600) * 4 // 4 points per hour
        let now = Date()
        
        errorData = (0..<dataPoints).map { index in
            let timestamp = now.addingTimeInterval(-timeRange.seconds + (timeRange.seconds / Double(dataPoints) * Double(index)))
            
            // Simulate realistic patterns
            let hourOfDay = Calendar.current.component(.hour, from: timestamp)
            let isPeakHour = (9...17).contains(hourOfDay)
            
            let baseErrorRate = isPeakHour ? 0.02 : 0.01
            let errorRate = baseErrorRate + Double.random(in: -0.01...0.02)
            
            let baseResponseTime = isPeakHour ? 250.0 : 150.0
            let responseTime = baseResponseTime + Double.random(in: -50...100)
            
            let availability = 0.99 + Double.random(in: -0.02...0.01)
            let throughput = isPeakHour ? 100.0 : 50.0 + Double.random(in: -20...20)
            
            let totalRequests = Int(throughput * 3600)
            let errorCount = Int(Double(totalRequests) * errorRate)
            let successCount = totalRequests - errorCount
            
            return ErrorDataPoint(
                timestamp: timestamp,
                errorRate: max(0, errorRate),
                responseTime: max(0, responseTime),
                availability: min(1.0, max(0, availability)),
                throughput: max(0, throughput),
                errorCount: errorCount,
                successCount: successCount
            )
        }
        
        // Generate error distribution
        errorDistribution = [
            ErrorCategory(
                name: "Authentication",
                count: 142,
                percentage: 0.35,
                icon: "lock.slash",
                color: .red,
                severity: .high
            ),
            ErrorCategory(
                name: "Rate Limit",
                count: 98,
                percentage: 0.24,
                icon: "speedometer",
                color: .orange,
                severity: .medium
            ),
            ErrorCategory(
                name: "Network",
                count: 76,
                percentage: 0.19,
                icon: "wifi.slash",
                color: .blue,
                severity: .medium
            ),
            ErrorCategory(
                name: "Timeout",
                count: 54,
                percentage: 0.13,
                icon: "clock.badge.exclamationmark",
                color: .purple,
                severity: .low
            ),
            ErrorCategory(
                name: "Server",
                count: 36,
                percentage: 0.09,
                icon: "server.rack",
                color: .pink,
                severity: .critical
            )
        ]
    }
    
    private func calculateMetrics(for timeRange: TimeRange) {
        guard !errorData.isEmpty else { return }
        
        let totalErrors = errorData.reduce(0) { $0 + $1.errorCount }
        let totalSuccess = errorData.reduce(0) { $0 + $1.successCount }
        let totalRequests = totalErrors + totalSuccess
        
        metrics.totalRequests = totalRequests
        metrics.failedRequests = totalErrors
        metrics.errorRate = totalRequests > 0 ? Double(totalErrors) / Double(totalRequests) : 0
        metrics.averageResponseTime = errorData.reduce(0) { $0 + $1.responseTime } / Double(errorData.count)
        metrics.availability = errorData.reduce(0) { $0 + $1.availability } / Double(errorData.count)
        metrics.throughput = errorData.reduce(0) { $0 + $1.throughput } / Double(errorData.count)
        
        // Calculate trends (simulate)
        let previousPeriodErrorRate = metrics.errorRate * 1.1
        let errorRateChange = ((metrics.errorRate - previousPeriodErrorRate) / previousPeriodErrorRate) * 100
        
        if abs(errorRateChange) < 5 {
            metrics.errorRateTrend = .stable
        } else if errorRateChange < 0 {
            metrics.errorRateTrend = .improving(abs(errorRateChange))
        } else {
            metrics.errorRateTrend = .degrading(errorRateChange)
        }
        
        // Similar for other trends
        metrics.responseTimeTrend = .improving(8.5)
        metrics.availabilityTrend = .stable
        metrics.throughputTrend = .degrading(3.2)
    }
    
    private func analyzeHealth() {
        let errorScore = (1 - metrics.errorRate) * 100
        let availabilityScore = metrics.availability * 100
        let responseTimeScore = max(0, 100 - (metrics.averageResponseTime / 10))
        
        let overallScore = (errorScore + availabilityScore + responseTimeScore) / 3
        
        if overallScore >= 90 {
            healthScore = .excellent
        } else if overallScore >= 75 {
            healthScore = .good
        } else if overallScore >= 60 {
            healthScore = .fair
        } else if overallScore >= 40 {
            healthScore = .poor
        } else {
            healthScore = .critical
        }
    }
    
    private func identifyTopIssues() {
        topIssues = [
            Issue(
                title: "Authentication Failures Spike",
                description: "Increased 401 errors from API key validation",
                impact: .high,
                affectedUsers: 234,
                occurrences: 142,
                firstSeen: Date().addingTimeInterval(-7200),
                lastSeen: Date().addingTimeInterval(-300),
                status: .investigating
            ),
            Issue(
                title: "Rate Limiting During Peak Hours",
                description: "Users hitting rate limits between 2-4 PM",
                impact: .medium,
                affectedUsers: 156,
                occurrences: 98,
                firstSeen: Date().addingTimeInterval(-86400),
                lastSeen: Date().addingTimeInterval(-3600),
                status: .active
            ),
            Issue(
                title: "Intermittent Network Timeouts",
                description: "Connection timeouts to eu-west region",
                impact: .medium,
                affectedUsers: 89,
                occurrences: 76,
                firstSeen: Date().addingTimeInterval(-172800),
                lastSeen: Date().addingTimeInterval(-1800),
                status: .monitoring
            )
        ]
    }
    
    private func generateRecommendations() {
        recommendations = [
            Recommendation(
                title: "Implement Request Caching",
                description: "Cache frequently requested completions to reduce API calls by up to 40%",
                impact: "Reduce error rate by 15-20% and improve response times",
                effort: .medium,
                category: .performance,
                priority: .high
            ),
            Recommendation(
                title: "Add Circuit Breaker Pattern",
                description: "Prevent cascading failures with automatic circuit breaking",
                impact: "Improve system resilience and reduce error propagation",
                effort: .medium,
                category: .reliability,
                priority: .urgent
            ),
            Recommendation(
                title: "Optimize Retry Logic",
                description: "Implement exponential backoff with jitter for better retry distribution",
                impact: "Reduce retry storms and improve success rate",
                effort: .low,
                category: .reliability,
                priority: .high
            ),
            Recommendation(
                title: "Enable Request Queuing",
                description: "Queue requests during high load periods to smooth traffic",
                impact: "Handle 2x more concurrent users without errors",
                effort: .high,
                category: .scalability,
                priority: .medium
            )
        ]
    }
}

// UI Components
struct DashboardHeaderView: View {
    @ObservedObject var dashboard: ErrorDashboard
    @Binding var selectedTimeRange: TimeRange
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error Dashboard")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("System health and error analytics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Time range selector
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
            }
            
            // Health score
            HealthScoreCard(healthScore: dashboard.healthScore)
        }
    }
}

struct HealthScoreCard: View {
    let healthScore: ErrorDashboard.HealthScore
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: healthScore.icon)
                .font(.title)
                .foregroundColor(healthScore.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("System Health")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(healthScore.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(healthScore.color)
                    
                    // Score gauge
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 8)
                        
                        Capsule()
                            .fill(healthScore.color)
                            .frame(width: CGFloat(healthScore.score), height: 8)
                    }
                    
                    Text("\(healthScore.score)/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            
            Spacer()
            
            if dashboard.isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: { dashboard.refresh(for: .last24Hours) }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .padding()
        .background(healthScore.color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct KeyMetricsView: View {
    @ObservedObject var dashboard: ErrorDashboard
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Error Rate",
                value: String(format: "%.2f%%", dashboard.metrics.errorRate * 100),
                trend: dashboard.metrics.errorRateTrend,
                icon: "exclamationmark.circle",
                color: .red
            )
            
            MetricCard(
                title: "Avg Response Time",
                value: String(format: "%.0f ms", dashboard.metrics.averageResponseTime),
                trend: dashboard.metrics.responseTimeTrend,
                icon: "timer",
                color: .orange
            )
            
            MetricCard(
                title: "Availability",
                value: String(format: "%.2f%%", dashboard.metrics.availability * 100),
                trend: dashboard.metrics.availabilityTrend,
                icon: "checkmark.shield",
                color: .green
            )
            
            MetricCard(
                title: "Throughput",
                value: String(format: "%.1f req/s", dashboard.metrics.throughput),
                trend: dashboard.metrics.throughputTrend,
                icon: "arrow.left.arrow.right",
                color: .blue
            )
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let trend: ErrorDashboard.DashboardMetrics.Trend
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(trend.description)
                    .font(.caption2)
                    .foregroundColor(trend.color)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ErrorTrendsChartView: View {
    @ObservedObject var dashboard: ErrorDashboard
    let timeRange: TimeRange
    @Binding var selectedMetric: MetricType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Error Trends")
                    .font(.headline)
                
                Spacer()
                
                // Metric selector
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Chart
            Chart(dashboard.errorData) { dataPoint in
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value(selectedMetric.rawValue, metricValue(for: dataPoint))
                )
                .foregroundStyle(selectedMetric.color)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value(selectedMetric.rawValue, metricValue(for: dataPoint))
                )
                .foregroundStyle(selectedMetric.color.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
            .chartYAxisLabel(selectedMetric.unit)
            .chartXAxis {
                AxisMarks(preset: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            
            // Legend
            HStack(spacing: 20) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(metric.color)
                            .frame(width: 8, height: 8)
                        
                        Text(metric.rawValue)
                            .font(.caption)
                            .foregroundColor(selectedMetric == metric ? .primary : .secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    func metricValue(for dataPoint: ErrorDashboard.ErrorDataPoint) -> Double {
        switch selectedMetric {
        case .errorRate:
            return dataPoint.errorRate * 100
        case .responseTime:
            return dataPoint.responseTime
        case .availability:
            return dataPoint.availability * 100
        case .throughput:
            return dataPoint.throughput
        }
    }
}

struct ErrorDistributionView: View {
    @ObservedObject var dashboard: ErrorDashboard
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Error Distribution")
                .font(.headline)
            
            // Pie chart representation
            HStack(spacing: 20) {
                // Chart
                ZStack {
                    ForEach(Array(dashboard.errorDistribution.enumerated()), id: \.element.id) { index, category in
                        PieSlice(
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index),
                            color: category.color
                        )
                    }
                }
                .frame(width: 150, height: 150)
                
                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(dashboard.errorDistribution) { category in
                        ErrorCategoryRow(category: category)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    func startAngle(for index: Int) -> Angle {
        let percentages = dashboard.errorDistribution.prefix(index).map { $0.percentage }
        let sum = percentages.reduce(0, +)
        return Angle(degrees: sum * 360)
    }
    
    func endAngle(for index: Int) -> Angle {
        let percentages = dashboard.errorDistribution.prefix(index + 1).map { $0.percentage }
        let sum = percentages.reduce(0, +)
        return Angle(degrees: sum * 360)
    }
}

struct PieSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle - .degrees(90),
                    endAngle: endAngle - .degrees(90),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

struct ErrorCategoryRow: View {
    let category: ErrorDashboard.ErrorCategory
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)
            
            Image(systemName: category.icon)
                .font(.caption)
                .foregroundColor(category.color)
            
            Text(category.name)
                .font(.caption)
                .frame(width: 80, alignment: .leading)
            
            Text("\(category.count)")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
            
            Text("(\(Int(category.percentage * 100))%)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct HealthIndicatorsView: View {
    @ObservedObject var dashboard: ErrorDashboard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Indicators")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                HealthIndicator(
                    title: "API Endpoints",
                    status: .operational,
                    uptime: 99.95
                )
                
                HealthIndicator(
                    title: "Authentication",
                    status: .degraded,
                    uptime: 98.2
                )
                
                HealthIndicator(
                    title: "Rate Limiting",
                    status: .partial,
                    uptime: 99.1
                )
                
                HealthIndicator(
                    title: "Cache Layer",
                    status: .operational,
                    uptime: 100
                )
                
                HealthIndicator(
                    title: "Streaming",
                    status: .operational,
                    uptime: 99.8
                )
                
                HealthIndicator(
                    title: "Error Handling",
                    status: .operational,
                    uptime: 100
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct HealthIndicator: View {
    let title: String
    let status: ServiceStatus
    let uptime: Double
    
    enum ServiceStatus {
        case operational
        case degraded
        case partial
        case outage
        
        var color: Color {
            switch self {
            case .operational: return .green
            case .degraded: return .yellow
            case .partial: return .orange
            case .outage: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .operational: return "checkmark.circle.fill"
            case .degraded: return "exclamationmark.triangle.fill"
            case .partial: return "exclamationmark.circle.fill"
            case .outage: return "xmark.circle.fill"
            }
        }
        
        var label: String {
            switch self {
            case .operational: return "Operational"
            case .degraded: return "Degraded"
            case .partial: return "Partial Outage"
            case .outage: return "Outage"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(status.label)
                .font(.caption)
                .foregroundColor(status.color)
            
            HStack {
                Text("Uptime:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.2f%%", uptime))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TopIssuesView: View {
    @ObservedObject var dashboard: ErrorDashboard
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Issues")
                    .font(.headline)
                
                Spacer()
                
                Text("\(dashboard.topIssues.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(dashboard.topIssues) { issue in
                IssueCard(issue: issue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct IssueCard: View {
    let issue: ErrorDashboard.Issue
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(issue.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    ImpactBadge(impact: issue.impact)
                    StatusBadge(status: issue.status)
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                HStack(spacing: 20) {
                    Label("\(issue.affectedUsers) users", systemImage: "person.2")
                    Label("\(issue.occurrences) occurrences", systemImage: "number")
                    Label("First: \(issue.firstSeen, style: .relative)", systemImage: "clock")
                    Label("Last: \(issue.lastSeen, style: .relative)", systemImage: "clock.fill")
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

struct ImpactBadge: View {
    let impact: ErrorDashboard.Issue.Impact
    
    var body: some View {
        Text(impact.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(impact.color)
            .cornerRadius(4)
    }
}

struct StatusBadge: View {
    let status: ErrorDashboard.Issue.Status
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .cornerRadius(4)
    }
}

struct PerformanceImpactView: View {
    @ObservedObject var dashboard: ErrorDashboard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Impact")
                .font(.headline)
            
            HStack(spacing: 20) {
                PerformanceMetric(
                    label: "Lost Requests",
                    value: "\(dashboard.metrics.failedRequests)",
                    sublabel: "in period",
                    color: .red
                )
                
                PerformanceMetric(
                    label: "Extra Latency",
                    value: "+\(Int(dashboard.metrics.averageResponseTime * 0.15))ms",
                    sublabel: "from errors",
                    color: .orange
                )
                
                PerformanceMetric(
                    label: "Revenue Impact",
                    value: "$\(dashboard.metrics.failedRequests * 2)",
                    sublabel: "estimated loss",
                    color: .purple
                )
                
                PerformanceMetric(
                    label: "User Satisfaction",
                    value: "-\(Int(dashboard.metrics.errorRate * 200))%",
                    sublabel: "from baseline",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct PerformanceMetric: View {
    let label: String
    let value: String
    let sublabel: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .monospacedDigit()
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(sublabel)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecommendationsView: View {
    @ObservedObject var dashboard: ErrorDashboard
    @State private var selectedRecommendation: ErrorDashboard.Recommendation?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Recommendations", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                Spacer()
                
                Text("\(dashboard.recommendations.filter { $0.priority.rawValue >= 3 }.count) high priority")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            ForEach(dashboard.recommendations) { recommendation in
                RecommendationCard(
                    recommendation: recommendation,
                    isSelected: selectedRecommendation?.id == recommendation.id,
                    action: {
                        selectedRecommendation = selectedRecommendation?.id == recommendation.id ? nil : recommendation
                    }
                )
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RecommendationCard: View {
    let recommendation: ErrorDashboard.Recommendation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: recommendation.category.icon)
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isSelected {
                        Text(recommendation.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    PriorityBadge(priority: recommendation.priority)
                    EffortBadge(effort: recommendation.effort)
                }
                
                Button(action: action) {
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    Label(recommendation.impact, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    HStack {
                        Label(recommendation.category.rawValue, systemImage: recommendation.category.icon)
                        Label("Effort: \(recommendation.effort.rawValue)", systemImage: "hammer")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(isSelected ? Color.yellow.opacity(0.1) : Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct PriorityBadge: View {
    let priority: ErrorDashboard.Recommendation.Priority
    
    var body: some View {
        Text(priority.label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priority.color)
            .cornerRadius(4)
    }
}

struct EffortBadge: View {
    let effort: ErrorDashboard.Recommendation.Effort
    
    var body: some View {
        Text(effort.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(effort.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(effort.color, lineWidth: 1)
            )
    }
}