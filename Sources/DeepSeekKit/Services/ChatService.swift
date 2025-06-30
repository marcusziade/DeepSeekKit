import Foundation

/// Default implementation of the chat service protocol.
///
/// `ChatService` handles all chat-related API interactions with the DeepSeek platform,
/// including both standard and streaming completions. It manages request building,
/// network communication, and response parsing.
///
/// ## Features
/// - Standard chat completions with full response
/// - Streaming chat completions for real-time output
/// - Automatic handling of model-specific constraints
/// - Platform-optimized streaming implementations
///
/// ## Implementation Details
/// The service uses dependency injection for flexibility:
/// - `NetworkingProtocol` for standard HTTP requests
/// - `StreamingHandler` for server-sent events
/// - `RequestBuilder` for constructing API requests
///
/// - Note: This class is internal and accessed through `DeepSeekClient.chat`.
final class ChatService: ChatServiceProtocol {
    private let networking: NetworkingProtocol
    private let requestBuilder: RequestBuilder
    private let streamingHandler: StreamingHandler
    private let apiKey: String
    
    init(
        networking: NetworkingProtocol,
        requestBuilder: RequestBuilder,
        streamingHandler: StreamingHandler,
        apiKey: String
    ) {
        self.networking = networking
        self.requestBuilder = requestBuilder
        self.streamingHandler = streamingHandler
        self.apiKey = apiKey
    }
    
    func createCompletion(_ request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        // Ensure streaming is disabled for non-streaming request
        var nonStreamingRequest = request
        if request.stream == true {
            nonStreamingRequest = ChatCompletionRequest(
                model: request.model,
                messages: request.messages,
                temperature: request.temperature,
                topP: request.topP,
                maxTokens: request.maxTokens,
                stream: false,
                stop: request.stop,
                frequencyPenalty: request.frequencyPenalty,
                presencePenalty: request.presencePenalty,
                responseFormat: request.responseFormat,
                tools: request.tools,
                toolChoice: request.toolChoice,
                logprobs: request.logprobs,
                topLogprobs: request.topLogprobs
            )
        }
        
        let urlRequest = try requestBuilder.chatCompletionRequest(nonStreamingRequest)
        return try await networking.perform(urlRequest, expecting: ChatCompletionResponse.self)
    }
    
    func createStreamingCompletion(_ request: ChatCompletionRequest) -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        let baseURL = URL(string: "https://api.deepseek.com/v1")!
        return streamingHandler.streamChatCompletion(request, apiKey: apiKey, baseURL: baseURL)
    }
    
    func createCompletion(_ request: CompletionRequest) async throws -> CompletionResponse {
        let urlRequest = try requestBuilder.completionRequest(request)
        return try await networking.perform(urlRequest, expecting: CompletionResponse.self)
    }
}