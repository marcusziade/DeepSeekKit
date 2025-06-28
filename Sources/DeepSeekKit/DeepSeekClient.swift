import Foundation

/// The main DeepSeek API client.
///
/// This client provides access to all DeepSeek API functionality including
/// chat completions, model information, and account balance queries.
///
/// ## Example Usage
/// ```swift
/// let client = DeepSeekClient(apiKey: "your-api-key")
///
/// // Create a chat completion
/// let response = try await client.chat.createCompletion(
///     ChatCompletionRequest(
///         model: .chat,
///         messages: [
///             ChatMessage(role: .user, content: "Hello, how are you?")
///         ]
///     )
/// )
/// print(response.choices.first?.message.content ?? "")
/// ```
public final class DeepSeekClient: DeepSeekProtocol {
    public let apiKey: String
    public let baseURL: URL
    public let chat: ChatServiceProtocol
    public let models: ModelServiceProtocol
    public let balance: BalanceServiceProtocol
    
    /// Creates a new DeepSeek client.
    ///
    /// - Parameters:
    ///   - apiKey: Your DeepSeek API key.
    ///   - baseURL: The base URL for API requests (defaults to production).
    ///   - session: URLSession to use for networking (defaults to shared).
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.deepseek.com/v1")!,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        
        let networking = URLSessionNetworking(session: session)
        let requestBuilder = RequestBuilder(baseURL: baseURL, apiKey: apiKey)
        
        // Use platform-specific streaming handler
        let streamingHandler: StreamingHandler
        #if os(Linux)
        streamingHandler = CURLStreamingHandler()
        #else
        streamingHandler = URLSessionStreamingHandler()
        #endif
        
        self.chat = ChatService(
            networking: networking,
            requestBuilder: requestBuilder,
            streamingHandler: streamingHandler,
            apiKey: apiKey
        )
        
        self.models = ModelService(
            networking: networking,
            requestBuilder: requestBuilder
        )
        
        self.balance = BalanceService(
            networking: networking,
            requestBuilder: requestBuilder
        )
    }
}