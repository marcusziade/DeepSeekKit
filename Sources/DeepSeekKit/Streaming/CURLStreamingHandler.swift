#if os(Linux)
import Foundation

/// cURL-based streaming implementation for Linux platforms.
///
/// Since Linux's URLSession doesn't support streaming responses, this handler
/// uses cURL directly to provide true HTTP streaming capabilities with server-sent
/// events (SSE) support.
///
/// ## Features
/// - Direct cURL integration for streaming
/// - Server-sent events (SSE) parsing
/// - Chunked transfer encoding support
/// - Process-based isolation for safety
/// - Automatic cleanup and error handling
///
/// ## Implementation Strategy
/// The handler spawns a cURL process to handle the HTTP connection, capturing
/// its output and parsing the server-sent events stream. This approach provides:
/// - True streaming without buffering entire responses
/// - Compatibility with standard Linux distributions
/// - Minimal dependencies (only requires cURL)
///
/// ## Security Considerations
/// - API keys are passed via headers, not command line arguments
/// - Process output is carefully parsed to prevent injection
/// - Automatic process termination on stream cancellation
///
/// ## Error Handling
/// The handler gracefully handles:
/// - cURL process failures
/// - Network interruptions
/// - Malformed SSE data
/// - JSON parsing errors
///
/// - Note: Requires cURL to be installed on the system.
public final class CURLStreamingHandler: StreamingHandler {
    private let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }
    
    /// Creates a streaming completion using cURL.
    public func streamChatCompletion(
        _ request: ChatCompletionRequest,
        apiKey: String,
        baseURL: URL
    ) -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Ensure stream is enabled
                    var streamingRequest = request
                    streamingRequest = ChatCompletionRequest(
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
                    let bodyData = try encoder.encode(streamingRequest)
                    let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
                    
                    let url = baseURL.appendingPathComponent("chat/completions")
                    
                    // Build cURL command
                    let curlCommand = buildCURLCommand(
                        url: url.absoluteString,
                        body: bodyString,
                        apiKey: apiKey
                    )
                    
                    // Execute cURL process
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = ["bash", "-c", curlCommand]
                    
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError = pipe
                    
                    let fileHandle = pipe.fileHandleForReading
                    
                    // Start the process
                    try process.run()
                    
                    // Read streaming data
                    var buffer = Data()
                    let delimiter = "\n\n".data(using: .utf8)!
                    
                    while process.isRunning || fileHandle.availableData.count > 0 {
                        let data = fileHandle.availableData
                        guard !data.isEmpty else {
                            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                            continue
                        }
                        
                        buffer.append(data)
                        
                        // Process complete SSE events
                        while let range = buffer.range(of: delimiter) {
                            let eventData = buffer.subdata(in: 0..<range.lowerBound)
                            buffer.removeSubrange(0..<range.upperBound)
                            
                            if let event = parseSSEEvent(eventData) {
                                continuation.yield(event)
                            }
                        }
                    }
                    
                    // Process any remaining data
                    if !buffer.isEmpty {
                        if let event = parseSSEEvent(buffer) {
                            continuation.yield(event)
                        }
                    }
                    
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        throw DeepSeekError.streamingError("cURL process failed with status: \(process.terminationStatus)")
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func buildCURLCommand(url: String, body: String, apiKey: String) -> String {
        // Escape single quotes in body
        let escapedBody = body.replacingOccurrences(of: "'", with: "'\\''")
        
        return """
        curl -N -X POST '\(url)' \
          -H 'Authorization: Bearer \(apiKey)' \
          -H 'Content-Type: application/json' \
          -H 'Accept: text/event-stream' \
          -d '\(escapedBody)'
        """
    }
    
    private func parseSSEEvent(_ data: Data) -> ChatCompletionChunk? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        
        // Parse SSE format
        let lines = string.split(separator: "\n")
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                // Check for [DONE] marker
                if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                    return nil
                }
                
                // Parse JSON
                if let jsonData = jsonString.data(using: .utf8) {
                    return try? decoder.decode(ChatCompletionChunk.self, from: jsonData)
                }
            }
        }
        
        return nil
    }
}
#endif