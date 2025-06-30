#if canImport(Darwin)
import Foundation

/// URLSession-based streaming implementation for Apple platforms.
///
/// This handler provides native streaming support using URLSession's async/await
/// capabilities, offering optimal performance and integration on iOS, macOS, tvOS,
/// watchOS, and visionOS.
///
/// ## Features
/// - Native async/await streaming with `URLSession.bytes`
/// - Automatic task cancellation on stream termination
/// - Server-sent events (SSE) parsing
/// - Proper error propagation and handling
///
/// ## Implementation Details
/// The handler:
/// 1. Creates an async stream for the response
/// 2. Processes server-sent events line by line
/// 3. Parses JSON chunks from the event data
/// 4. Handles special `[DONE]` markers
/// 5. Provides automatic cleanup on cancellation
///
/// ## Platform Availability
/// This implementation is only available on Apple platforms that support
/// URLSession's async streaming APIs (iOS 15.0+, macOS 12.0+, etc.)
///
/// - Note: For Linux support, see `CURLStreamingHandler`.
public final class URLSessionStreamingHandler: StreamingHandler {
    public init() {}
    
    public func streamChatCompletion(
        _ request: ChatCompletionRequest,
        apiKey: String,
        baseURL: URL
    ) -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try self.createURLRequest(
                        for: request,
                        apiKey: apiKey,
                        baseURL: baseURL
                    )
                    
                    // Create streaming task
                    let session = URLSession(configuration: .default)
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw DeepSeekError.invalidRequest("Invalid response type")
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw DeepSeekError.httpError(statusCode: httpResponse.statusCode)
                    }
                    
                    // Process the stream
                    var buffer = ""
                    
                    for try await byte in bytes {
                        buffer.append(Character(UnicodeScalar(byte)))
                        
                        // Check for complete SSE messages
                        while let range = buffer.range(of: "\n\n") {
                            let message = String(buffer[..<range.lowerBound])
                            buffer.removeSubrange(..<range.upperBound)
                            
                            if message.hasPrefix("data: ") {
                                let jsonString = String(message.dropFirst(6))
                                
                                if jsonString == "[DONE]" {
                                    continuation.finish()
                                    return
                                }
                                
                                do {
                                    let chunk = try JSONDecoder().decode(
                                        ChatCompletionChunk.self,
                                        from: jsonString.data(using: .utf8)!
                                    )
                                    continuation.yield(chunk)
                                } catch {
                                    // Skip malformed chunks
                                    continue
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    private func createURLRequest(
        for request: ChatCompletionRequest,
        apiKey: String,
        baseURL: URL
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // Create a new request with streaming enabled
        let streamingRequest = ChatCompletionRequest(
            model: request.model,
            messages: request.messages,
            temperature: request.temperature,
            topP: request.topP,
            maxTokens: request.maxTokens,
            stream: true,
            stop: request.stop,
            frequencyPenalty: request.frequencyPenalty,
            presencePenalty: request.presencePenalty,
            responseFormat: request.responseFormat,
            tools: request.tools,
            toolChoice: request.toolChoice,
            logprobs: request.logprobs,
            topLogprobs: request.topLogprobs
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(streamingRequest)
        
        return urlRequest
    }
}
#endif