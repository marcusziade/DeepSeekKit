import Foundation

/// Response containing user balance information.
public struct BalanceResponse: Codable, Sendable {
    /// Whether the balance is available.
    public let isAvailable: Bool
    
    /// Array of balance information for different currencies.
    public let balanceInfos: [Balance]
    
    private enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
    
    /// Legacy support for old format
    public var balances: [Balance] {
        return balanceInfos
    }
}

/// Balance information for a specific currency.
public struct Balance: Codable, Sendable {
    /// The currency (CNY or USD).
    public let currency: String
    
    /// Total balance amount.
    public let totalBalance: String
    
    /// Granted balance amount.
    public let grantedBalance: String
    
    /// Topped up balance amount.
    public let toppedUpBalance: String
    
    private enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}