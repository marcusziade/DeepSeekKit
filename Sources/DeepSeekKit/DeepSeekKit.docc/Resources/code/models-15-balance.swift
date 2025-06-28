import SwiftUI
import DeepSeekKit

struct UsageTracking: View {
    @StateObject private var client = DeepSeekClient()
    @State private var balance: BalanceInfo?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var lastRefreshed = Date()
    @State private var showingLowBalanceAlert = false
    
    struct BalanceInfo {
        let totalBalance: Double
        let balanceInfos: [CurrencyBalance]
        let currency: String
        
        var isLowBalance: Bool {
            totalBalance < 5.0 // Alert if below $5
        }
        
        var balanceStatus: BalanceStatus {
            if totalBalance > 50 {
                return .healthy
            } else if totalBalance > 10 {
                return .moderate
            } else {
                return .low
            }
        }
        
        enum BalanceStatus {
            case healthy, moderate, low
            
            var color: Color {
                switch self {
                case .healthy: return .green
                case .moderate: return .orange
                case .low: return .red
                }
            }
            
            var icon: String {
                switch self {
                case .healthy: return "checkmark.circle.fill"
                case .moderate: return "exclamationmark.circle.fill"
                case .low: return "xmark.circle.fill"
                }
            }
            
            var message: String {
                switch self {
                case .healthy: return "Your balance is healthy"
                case .moderate: return "Consider topping up soon"
                case .low: return "Low balance - top up needed"
                }
            }
        }
    }
    
    struct CurrencyBalance {
        let currency: String
        let totalBalance: Double
        let grantedBalance: Double
        let toppedUpBalance: Double
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Text("Account Balance")
                            .font(.largeTitle)
                            .bold()
                        
                        if balance != nil {
                            Text("Last updated: \(lastRefreshed, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Balance Card
                    if let balance = balance {
                        BalanceCardView(balance: balance)
                            .alert("Low Balance Warning", isPresented: $showingLowBalanceAlert) {
                                Button("OK") { }
                                Button("Top Up") {
                                    // Open top-up URL
                                }
                            } message: {
                                Text("Your balance is below $5. Consider topping up to avoid service interruption.")
                            }
                    }
                    
                    // Refresh Button
                    Button(action: checkBalance) {
                        Label(
                            isLoading ? "Checking..." : "Refresh Balance",
                            systemImage: "arrow.clockwise"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Balance Breakdown
                    if let balance = balance {
                        BalanceBreakdownView(balanceInfos: balance.balanceInfos)
                    }
                    
                    // Usage Tips
                    UsageTipsView()
                    
                    // Cost Reference
                    CostReferenceView()
                }
                .padding()
            }
            .navigationBarHidden(true)
            .onAppear {
                checkBalance()
            }
        }
    }
    
    private func checkBalance() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let response = try await client.balance()
                
                // Parse balance response
                let balanceInfos = response.balanceInfos.map { info in
                    CurrencyBalance(
                        currency: info.currency,
                        totalBalance: info.totalBalance,
                        grantedBalance: info.grantedBalance,
                        toppedUpBalance: info.toppedUpBalance
                    )
                }
                
                balance = BalanceInfo(
                    totalBalance: response.totalBalance,
                    balanceInfos: balanceInfos,
                    currency: response.currency
                )
                
                lastRefreshed = Date()
                
                // Check for low balance
                if balance?.isLowBalance == true {
                    showingLowBalanceAlert = true
                }
                
            } catch {
                errorMessage = "Failed to fetch balance: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
}

struct BalanceCardView: View {
    let balance: UsageTracking.BalanceInfo
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Icon
            Image(systemName: balance.balanceStatus.icon)
                .font(.system(size: 50))
                .foregroundColor(balance.balanceStatus.color)
            
            // Balance Amount
            VStack(spacing: 5) {
                Text("Current Balance")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(String(format: "$%.2f", balance.totalBalance))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(balance.balanceStatus.color)
                
                Text(balance.currency)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Status Message
            Text(balance.balanceStatus.message)
                .font(.subheadline)
                .foregroundColor(balance.balanceStatus.color)
            
            // Visual Balance Indicator
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 20)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(balance.balanceStatus.color)
                        .frame(
                            width: geometry.size.width * min(balance.totalBalance / 100, 1),
                            height: 20
                        )
                }
            }
            .frame(height: 20)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct BalanceBreakdownView: View {
    let balanceInfos: [UsageTracking.CurrencyBalance]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Balance Breakdown")
                .font(.headline)
            
            ForEach(balanceInfos, id: \.currency) { info in
                VStack(alignment: .leading, spacing: 10) {
                    Text(info.currency)
                        .font(.subheadline)
                        .bold()
                    
                    HStack {
                        BalanceTypeRow(
                            type: "Granted",
                            amount: info.grantedBalance,
                            icon: "gift",
                            color: .blue
                        )
                        
                        Spacer()
                        
                        BalanceTypeRow(
                            type: "Topped Up",
                            amount: info.toppedUpBalance,
                            icon: "plus.circle",
                            color: .green
                        )
                        
                        Spacer()
                        
                        BalanceTypeRow(
                            type: "Total",
                            amount: info.totalBalance,
                            icon: "sum",
                            color: .purple
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
}

struct BalanceTypeRow: View {
    let type: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(String(format: "$%.2f", amount))
                .font(.subheadline)
                .bold()
            
            Text(type)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct UsageTipsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("Usage Tips")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TipRow(text: "Use the chat model for general tasks to save costs")
                TipRow(text: "Limit token usage by being concise in prompts")
                TipRow(text: "Monitor your balance regularly to avoid interruptions")
                TipRow(text: "Set up alerts for low balance notifications")
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text("•")
                .foregroundColor(.yellow)
            Text(text)
                .font(.caption)
        }
    }
}

struct CostReferenceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Cost Reference")
                .font(.headline)
            
            VStack(spacing: 8) {
                CostReferenceRow(
                    model: "Chat",
                    input: "$0.14 / 1M tokens",
                    output: "$0.28 / 1M tokens"
                )
                
                CostReferenceRow(
                    model: "Reasoner",
                    input: "$0.55 / 1M tokens",
                    output: "$2.19 / 1M tokens"
                )
            }
            
            Text("Average conversation: ~2,000 tokens")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
}

struct CostReferenceRow: View {
    let model: String
    let input: String
    let output: String
    
    var body: some View {
        HStack {
            Text(model)
                .font(.subheadline)
                .bold()
                .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading) {
                Text("Input: \(input)")
                    .font(.caption)
                Text("Output: \(output)")
                    .font(.caption)
            }
            
            Spacer()
        }
    }
}