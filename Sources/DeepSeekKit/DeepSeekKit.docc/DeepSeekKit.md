# ``DeepSeekKit``

A modern Swift SDK for integrating DeepSeek's powerful AI models into your applications.

@Metadata {
    @DisplayName("DeepSeekKit")
    @TitleHeading("Framework")
}

## Overview

DeepSeekKit provides a comprehensive, type-safe Swift interface to DeepSeek's AI models, including their advanced reasoning model and chat capabilities. Built with Swift's modern concurrency features and platform-specific optimizations, it delivers a seamless developer experience across all Apple platforms and Linux.

![DeepSeekKit Hero](deepseekkit-hero)

## Key Features

### 🚀 Type-Safe API Design
- Leverage Swift's strong type system for compile-time safety
- Comprehensive error handling with detailed error cases
- Full Codable support for all request and response types

### 🌊 Advanced Streaming
- Platform-optimized streaming implementations
- URLSession-based streaming for Apple platforms
- cURL-based streaming for Linux compatibility
- Real-time token generation with backpressure support

### 🎯 Multi-Platform Support
- **iOS 15.0+** - Build intelligent mobile applications
- **macOS 12.0+** - Create powerful desktop tools
- **tvOS 15.0+** - Enhance your TV apps with AI
- **watchOS 8.0+** - Add AI to your wrist
- **visionOS 1.0+** - Spatial computing with AI
- **Linux** - Server-side Swift applications

### 🧠 Model Capabilities
- **Chat Model** (`deepseek-chat`) - Fast, efficient conversational AI
- **Reasoning Model** (`deepseek-reasoner`) - Advanced multi-step reasoning
- **Function Calling** - Build AI agents with custom tools
- **JSON Mode** - Structured output generation
- **Fill-in-Middle** - Context-aware code completion

### ⚡ Performance & Reliability
- Zero external dependencies
- Automatic retry with exponential backoff
- Rate limiting and error recovery
- Connection pooling and keep-alive
- Comprehensive logging and debugging support

## Installation

### Swift Package Manager

Add DeepSeekKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/guitaripod/DeepSeekKit.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/guitaripod/DeepSeekKit.git`
3. Select version `1.0.0` or later

## Quick Start

### Basic Chat Completion

```swift
import DeepSeekKit

// Initialize the client
let client = DeepSeekClient(apiKey: "your-api-key")

// Create a simple chat completion
let response = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .chat,
        messages: [.user("Hello, DeepSeek!")]
    )
)

print(response.choices.first?.message.content ?? "")
```

### Streaming Responses

```swift
// Stream tokens as they're generated
let stream = client.chat.createStreamingCompletion(
    ChatCompletionRequest(
        model: .chat,
        messages: [.user("Write a short story")],
        stream: true
    )
)

for try await chunk in stream {
    if let content = chunk.choices.first?.delta.content {
        print(content, terminator: "")
    }
}
```

### Using the Reasoning Model

```swift
// Leverage advanced reasoning capabilities
let response = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .reasoner,
        messages: [.user("Solve: If a train travels 120 km in 2 hours, what is its average speed?")]
    )
)

// Access reasoning content
if let reasoningContent = response.choices.first?.message.reasoningContent {
    print("Reasoning process: \(reasoningContent)")
}
print("Answer: \(response.choices.first?.message.content ?? "")")
```

## Topics

### Essentials
Start here to understand the core components of DeepSeekKit.

- ``DeepSeekClient``
- ``ChatCompletionRequest``
- ``ChatMessage``
- ``DeepSeekModel``

### Request and Response Types
Types for building requests and handling responses.

- ``ChatCompletionResponse``
- ``ChatCompletionChunk``
- ``CompletionRequest``
- ``CompletionResponse``
- ``MessageRole``
- ``ResponseFormat``

### Services and Protocols
Core service protocols and implementations.

- ``ChatServiceProtocol``
- ``ModelServiceProtocol`` 
- ``BalanceServiceProtocol``
- ``DeepSeekProtocol``

### Function Calling
Build AI agents with custom tools and functions.

- ``Tool``
- ``FunctionBuilder``
- ``FunctionDefinition``
- ``ToolCall``
- ``ToolChoice``

### Error Handling
Comprehensive error handling for robust applications.

- ``DeepSeekError``
- ``APIError``

### Networking and Configuration
Low-level networking and configuration options.

- ``NetworkingProtocol``
- ``RequestBuilder``
- ``StreamingHandler``

### Platform-Specific Features
Platform-optimized implementations.

- ``URLSessionNetworking``
- ``URLSessionStreamingHandler``
- ``CURLStreamingHandler``

## See Also

- <doc:DeepSeekKit-Tutorials>