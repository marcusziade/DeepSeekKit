import Foundation

/// Implementation of the chat service.
final class ChatService: ChatServiceProtocol {
    private let networking: NetworkingProtocol
    private let requestBuilder: RequestBuilder
    private let streamingHandler: CURLStreamingHandler
    
    init(
        networking: NetworkingProtocol,
        requestBuilder: RequestBuilder,
        streamingHandler: CURLStreamingHandler
    ) {
        self.networking = networking
        self.requestBuilder = requestBuilder
        self.streamingHandler = streamingHandler
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
        return streamingHandler.streamChatCompletion(request, baseURL: baseURL)
    }
    
    func createCompletion(_ request: CompletionRequest) async throws -> CompletionResponse {
        let urlRequest = try requestBuilder.completionRequest(request)
        return try await networking.perform(urlRequest, expecting: CompletionResponse.self)
    }
}