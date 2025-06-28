# ``DeepSeekKit``

A modern Swift SDK for integrating DeepSeek's powerful AI models into your applications.

## Overview

DeepSeekKit provides a type-safe, platform-native way to interact with DeepSeek's AI models. Built with Swift's modern concurrency features, it supports all Apple platforms and Linux with native streaming capabilities.

![DeepSeekKit Hero](deepseekkit-hero)

## Features

- **Type-Safe API**: Leverage Swift's type system for compile-time safety
- **Native Streaming**: Platform-optimized streaming for real-time responses
- **Multi-Platform**: Supports iOS, macOS, tvOS, watchOS, visionOS, and Linux
- **Advanced Models**: Access both chat and reasoning models
- **Function Calling**: Build AI agents with custom tools
- **Fill-in-Middle**: Code completion with context awareness
- **Zero Dependencies**: Pure Swift implementation

## Getting Started

Add DeepSeekKit to your project:

```swift
dependencies: [
    .package(url: "https://github.com/marcusziade/DeepSeekKit.git", from: "1.0.0")
]
```

Create a client and start chatting:

```swift
import DeepSeekKit

let client = DeepSeekClient(apiKey: "your-api-key")
let response = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .chat,
        messages: [.user("Hello, DeepSeek!")]
    )
)
print(response.choices.first?.message.content ?? "")
```

## Topics

### Essentials

- ``DeepSeekClient``
- ``ChatCompletionRequest``
- ``ChatMessage``
- ``DeepSeekModel``

### Services

- ``ChatService``
- ``ModelService`` 
- ``BalanceService``

### Advanced Features

- ``Tool``
- ``FunctionBuilder``
- ``CompletionRequest``
- ``StreamingChunk``

### Networking

- ``DeepSeekConfiguration``
- ``DeepSeekError``

## See Also

- <doc:DeepSeekKit-Tutorials>