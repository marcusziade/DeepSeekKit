import Foundation

/// Protocol for handling streaming chat completions
public protocol StreamingHandler: Sendable {
    /// Stream a chat completion request
    /// - Parameters:
    ///   - request: The chat completion request
    ///   - apiKey: The API key for authentication
    ///   - baseURL: The base URL for the API
    /// - Returns: An async stream of chat completion chunks
    func streamChatCompletion(
        _ request: ChatCompletionRequest,
        apiKey: String,
        baseURL: URL
    ) -> AsyncThrowingStream<ChatCompletionChunk, Error>
}