import Foundation

/// Builds URLRequest objects for the DeepSeek API.
struct RequestBuilder {
    private let baseURL: URL
    private let apiKey: String
    private let encoder: JSONEncoder
    
    init(baseURL: URL, apiKey: String, encoder: JSONEncoder = JSONEncoder()) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.encoder = encoder
    }
    
    /// Creates a request for the chat completions endpoint.
    func chatCompletionRequest(_ request: ChatCompletionRequest) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("chat/completions")
        return try createPOSTRequest(url: url, body: request)
    }
    
    /// Creates a request for the completions endpoint (beta).
    func completionRequest(_ request: CompletionRequest) throws -> URLRequest {
        let betaURL = URL(string: "https://api.deepseek.com/beta")!
        let url = betaURL.appendingPathComponent("completions")
        return try createPOSTRequest(url: url, body: request)
    }
    
    /// Creates a request to list models.
    func listModelsRequest() -> URLRequest {
        let url = baseURL.appendingPathComponent("models")
        return createGETRequest(url: url)
    }
    
    /// Creates a request to get user balance.
    func getBalanceRequest() -> URLRequest {
        // Balance endpoint uses the root API URL without /v1
        let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!
        return createGETRequest(url: balanceURL)
    }
    
    // MARK: - Private Methods
    
    private func createGETRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
    
    private func createPOSTRequest<T: Encodable>(url: URL, body: T) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw DeepSeekError.encodingError(error)
        }
        
        return request
    }
}