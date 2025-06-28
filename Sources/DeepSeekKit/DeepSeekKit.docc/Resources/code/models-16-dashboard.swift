import SwiftUI
import DeepSeekKit
import Charts

struct UsageTracking: View {
    @StateObject private var viewModel = UsageDashboardViewModel()
    @State private var selectedTimeRange = TimeRange.today
    @State private var showingDetailSheet = false
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        
        var startDate: Date {
            let calendar = Calendar.current
            switch self {
            case .today:
                return calendar.startOfDay(for: Date())
            case .week:
                return calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            case .month:
                return calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HeaderView(
                        balance: viewModel.currentBalance,
                        onRefresh: { await viewModel.refreshData() }
                    )
                    
                    // Time Range Selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Summary Cards
                    SummaryCardsView(
                        stats: viewModel.getStats(for: selectedTimeRange),
                        balance: viewModel.currentBalance
                    )
                    
                    // Usage Chart
                    if !viewModel.usageData.isEmpty {
                        UsageChartView(
                            data: viewModel.getChartData(for: selectedTimeRange)
                        )
                    }
                    
                    // Model Breakdown
                    ModelBreakdownView(
                        modelUsage: viewModel.getModelUsage(for: selectedTimeRange)
                    )
                    
                    // Recent Sessions
                    RecentSessionsView(
                        sessions: viewModel.getRecentSessions(for: selectedTimeRange),
                        onSessionTap: { showingDetailSheet = true }
                    )
                    
                    // Cost Projections
                    CostProjectionView(
                        currentSpend: viewModel.getCurrentSpend(for: selectedTimeRange),
                        projectedSpend: viewModel.getProjectedMonthlySpend()
                    )
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Usage Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDetailSheet) {
                SessionDetailSheet(session: viewModel.selectedSession)
            }
            .onAppear {
                Task {
                    await viewModel.loadInitialData()
                }
            }
        }
    }
}

// View Model
class UsageDashboardViewModel: ObservableObject {
    @Published var currentBalance: Double = 0
    @Published var usageData: [UsageDataPoint] = []
    @Published var sessions: [ChatSession] = []
    @Published var selectedSession: ChatSession?
    
    private let client = DeepSeekClient()
    
    struct UsageDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let tokens: Int
        let cost: Double
        let model: DeepSeekModel
    }
    
    struct ChatSession: Identifiable {
        let id = UUID()
        let startTime: Date
        let duration: TimeInterval
        let model: DeepSeekModel
        let totalTokens: Int
        let cost: Double
        let messageCount: Int
    }
    
    struct UsageStats {
        let totalTokens: Int
        let totalCost: Double
        let sessionCount: Int
        let averageTokensPerSession: Int
    }
    
    struct ModelUsage: Identifiable {
        let id = UUID()
        let model: DeepSeekModel
        let tokens: Int
        let cost: Double
        let percentage: Double
    }
    
    func loadInitialData() async {
        // Load balance
        await refreshBalance()
        
        // Generate sample data (in real app, load from storage)
        generateSampleData()
    }
    
    func refreshData() async {
        await refreshBalance()
    }
    
    private func refreshBalance() async {
        do {
            let balance = try await client.balance()
            await MainActor.run {
                self.currentBalance = balance.totalBalance
            }
        } catch {
            print("Failed to fetch balance: \(error)")
        }
    }
    
    private func generateSampleData() {
        // Generate sample usage data for the dashboard
        let calendar = Calendar.current
        let now = Date()
        
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // Random sessions per day
            let sessionCount = Int.random(in: 1...5)
            
            for _ in 0..<sessionCount {
                let model: DeepSeekModel = Bool.random() ? .chat : .reasoner
                let tokens = Int.random(in: 500...5000)
                let cost = calculateCost(tokens: tokens, model: model)
                
                usageData.append(UsageDataPoint(
                    date: date,
                    tokens: tokens,
                    cost: cost,
                    model: model
                ))
                
                sessions.append(ChatSession(
                    startTime: date,
                    duration: TimeInterval(Int.random(in: 60...1800)),
                    model: model,
                    totalTokens: tokens,
                    cost: cost,
                    messageCount: Int.random(in: 2...20)
                ))
            }
        }
    }
    
    private func calculateCost(tokens: Int, model: DeepSeekModel) -> Double {
        let rates: (input: Double, output: Double) = model == .chat ? (0.14, 0.28) : (0.55, 2.19)
        let inputTokens = tokens / 2
        let outputTokens = tokens / 2
        return (Double(inputTokens) * rates.input + Double(outputTokens) * rates.output) / 1_000_000
    }
    
    func getStats(for timeRange: UsageTracking.TimeRange) -> UsageStats {
        let filteredData = usageData.filter { $0.date >= timeRange.startDate }
        let totalTokens = filteredData.reduce(0) { $0 + $1.tokens }
        let totalCost = filteredData.reduce(0) { $0 + $1.cost }
        let sessionCount = filteredData.count
        let avgTokens = sessionCount > 0 ? totalTokens / sessionCount : 0
        
        return UsageStats(
            totalTokens: totalTokens,
            totalCost: totalCost,
            sessionCount: sessionCount,
            averageTokensPerSession: avgTokens
        )
    }
    
    func getChartData(for timeRange: UsageTracking.TimeRange) -> [UsageDataPoint] {
        usageData.filter { $0.date >= timeRange.startDate }
            .sorted { $0.date < $1.date }
    }
    
    func getModelUsage(for timeRange: UsageTracking.TimeRange) -> [ModelUsage] {
        let filteredData = usageData.filter { $0.date >= timeRange.startDate }
        let totalTokens = filteredData.reduce(0) { $0 + $1.tokens }
        
        let chatData = filteredData.filter { $0.model == .chat }
        let reasonerData = filteredData.filter { $0.model == .reasoner }
        
        let chatTokens = chatData.reduce(0) { $0 + $1.tokens }
        let chatCost = chatData.reduce(0) { $0 + $1.cost }
        
        let reasonerTokens = reasonerData.reduce(0) { $0 + $1.tokens }
        let reasonerCost = reasonerData.reduce(0) { $0 + $1.cost }
        
        return [
            ModelUsage(
                model: .chat,
                tokens: chatTokens,
                cost: chatCost,
                percentage: totalTokens > 0 ? Double(chatTokens) / Double(totalTokens) : 0
            ),
            ModelUsage(
                model: .reasoner,
                tokens: reasonerTokens,
                cost: reasonerCost,
                percentage: totalTokens > 0 ? Double(reasonerTokens) / Double(totalTokens) : 0
            )
        ]
    }
    
    func getRecentSessions(for timeRange: UsageTracking.TimeRange) -> [ChatSession] {
        sessions.filter { $0.startTime >= timeRange.startDate }
            .sorted { $0.startTime > $1.startTime }
            .prefix(5)
            .map { $0 }
    }
    
    func getCurrentSpend(for timeRange: UsageTracking.TimeRange) -> Double {
        usageData.filter { $0.date >= timeRange.startDate }
            .reduce(0) { $0 + $1.cost }
    }
    
    func getProjectedMonthlySpend() -> Double {
        let last7Days = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentSpend = usageData.filter { $0.date >= last7Days }
            .reduce(0) { $0 + $1.cost }
        return recentSpend * 30 / 7
    }
}

// Supporting Views

struct HeaderView: View {
    let balance: Double
    let onRefresh: () async -> Void
    @State private var isRefreshing = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Balance")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(String(format: "$%.2f", balance))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    isRefreshing = true
                    await onRefresh()
                    isRefreshing = false
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
        }
        .padding()
    }
}

struct SummaryCardsView: View {
    let stats: UsageDashboardViewModel.UsageStats
    let balance: Double
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
            SummaryCard(
                title: "Total Tokens",
                value: "\(stats.totalTokens.formatted())",
                icon: "number",
                color: .blue
            )
            
            SummaryCard(
                title: "Total Spend",
                value: String(format: "$%.2f", stats.totalCost),
                icon: "dollarsign.circle",
                color: .green
            )
            
            SummaryCard(
                title: "Sessions",
                value: "\(stats.sessionCount)",
                icon: "bubble.left.and.bubble.right",
                color: .orange
            )
            
            SummaryCard(
                title: "Avg Tokens/Session",
                value: "\(stats.averageTokensPerSession)",
                icon: "chart.bar",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct UsageChartView: View {
    let data: [UsageDashboardViewModel.UsageDataPoint]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Usage Over Time")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(data) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Tokens", point.tokens)
                )
                .foregroundStyle(point.model == .chat ? Color.blue : Color.purple)
            }
            .frame(height: 200)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

struct ModelBreakdownView: View {
    let modelUsage: [UsageDashboardViewModel.ModelUsage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Model Usage Breakdown")
                .font(.headline)
            
            ForEach(modelUsage) { usage in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(usage.model.rawValue)
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Text("\(Int(usage.percentage * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(usage.model == .chat ? Color.blue : Color.purple)
                                .frame(width: geometry.size.width * usage.percentage, height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text("\(usage.tokens.formatted()) tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "$%.2f", usage.cost))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}

struct RecentSessionsView: View {
    let sessions: [UsageDashboardViewModel.ChatSession]
    let onSessionTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(sessions) { session in
                Button(action: onSessionTap) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.model.rawValue)
                                .font(.subheadline)
                                .bold()
                            Text("\(session.messageCount) messages • \(session.totalTokens) tokens")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "$%.3f", session.cost))
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Text(session.startTime, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}

struct CostProjectionView: View {
    let currentSpend: Double
    let projectedSpend: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cost Projection")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Current Period")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.2f", currentSpend))
                        .font(.title3)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Projected Monthly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.2f", projectedSpend))
                        .font(.title3)
                        .bold()
                        .foregroundColor(projectedSpend > 100 ? .red : .green)
                }
            }
            
            if projectedSpend > 100 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Your projected spend is high. Consider optimizing token usage.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct SessionDetailSheet: View {
    let session: UsageDashboardViewModel.ChatSession?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            if let session = session {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Session Details")
                        .font(.largeTitle)
                        .bold()
                    
                    // Session info implementation
                    Text("Model: \(session.model.rawValue)")
                    Text("Duration: \(Int(session.duration / 60)) minutes")
                    Text("Messages: \(session.messageCount)")
                    Text("Total Tokens: \(session.totalTokens)")
                    Text(String(format: "Cost: $%.3f", session.cost))
                    
                    Spacer()
                }
                .padding()
                .navigationBarItems(trailing: Button("Done") { dismiss() })
            } else {
                Text("No session selected")
            }
        }
    }
}