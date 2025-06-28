import Foundation

/// Protocol defining the chat completion service interface.
///
/// This protocol provides methods for creating chat completions with
/// both standard and streaming responses.
public protocol ChatServiceProtocol: Sendable {
    /// Creates a chat completion with the specified request.
    ///
    /// - Parameter request: The chat completion request configuration.
    /// - Returns: The chat completion response.
    /// - Throws: `DeepSeekError` if the request fails.
    func createCompletion(_ request: ChatCompletionRequest) async throws -> ChatCompletionResponse
    
    /// Creates a streaming chat completion with the specified request.
    ///
    /// - Parameter request: The chat completion request configuration.
    /// - Returns: An async stream of chat completion chunks.
    /// - Throws: `DeepSeekError` if the request fails.
    func createStreamingCompletion(_ request: ChatCompletionRequest) -> AsyncThrowingStream<ChatCompletionChunk, Error>
    
    /// Creates a code completion using Fill-in-Middle (FIM) mode (Beta).
    ///
    /// - Parameter request: The completion request configuration.
    /// - Returns: The completion response.
    /// - Throws: `DeepSeekError` if the request fails.
    func createCompletion(_ request: CompletionRequest) async throws -> CompletionResponse
}