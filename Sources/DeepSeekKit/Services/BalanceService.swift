import Foundation

/// Implementation of the balance service.
final class BalanceService: BalanceServiceProtocol {
    private let networking: NetworkingProtocol
    private let requestBuilder: RequestBuilder
    
    init(networking: NetworkingProtocol, requestBuilder: RequestBuilder) {
        self.networking = networking
        self.requestBuilder = requestBuilder
    }
    
    func getBalance() async throws -> BalanceResponse {
        let request = requestBuilder.getBalanceRequest()
        return try await networking.perform(request, expecting: BalanceResponse.self)
    }
}