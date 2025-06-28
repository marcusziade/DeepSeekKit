# DeepSeekKit

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI](https://github.com/marcusziade/DeepSeekKit/actions/workflows/ci.yml/badge.svg)](https://github.com/marcusziade/DeepSeekKit/actions/workflows/ci.yml)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

A comprehensive, production-ready Swift SDK for the DeepSeek API with full Linux support, protocol-oriented design, and complete feature coverage.

## Features

- ✅ **Complete API Coverage**: All DeepSeek API endpoints implemented
- 🚀 **Protocol-Oriented Design**: Clean, testable, and extensible architecture
- 🌊 **True HTTP Streaming**: cURL-based streaming for real-time responses
- 🐧 **Cross-Platform**: Full support for macOS and Linux
- 🔧 **Type-Safe**: Leverages Swift's type system for safe API interactions
- 📦 **Swift Package Manager**: Easy integration into your projects
- 🧪 **Well-Tested**: Comprehensive unit tests for reliability
- 📝 **DocC Documentation**: Rich API documentation
- 🛠 **CLI Tool**: Feature-complete command-line interface for testing

## Supported Features

- ✅ Chat Completions (DeepSeek-Chat & DeepSeek-Reasoner)
- ✅ Streaming Responses
- ✅ Function Calling
- ✅ JSON Mode
- ✅ Fill-in-Middle (FIM) Completions (Beta)
- ✅ Context Caching
- ✅ Model Listing
- ✅ Balance Queries
- ✅ Reasoning Mode (Chain of Thought)

## Requirements

- Swift 5.9+
- macOS 13+ / Linux (Ubuntu 20.04+)
- cURL (for streaming support)

## Installation

### Swift Package Manager

Add DeepSeekKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/marcusziade/DeepSeekKit", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: ["DeepSeekKit"]
    )
]
```

## Quick Start

```swift
import DeepSeekKit

// Initialize the client
let client = DeepSeekClient(apiKey: "your-api-key")

// Simple chat completion
let response = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .chat,
        messages: [
            .system("You are a helpful assistant"),
            .user("What is the capital of France?")
        ]
    )
)

print(response.choices.first?.message.content ?? "")
```

## Usage Examples

### Streaming Response

```swift
let request = ChatCompletionRequest(
    model: .chat,
    messages: [.user("Tell me a story")],
    stream: true
)

for try await chunk in client.chat.createStreamingCompletion(request) {
    if let content = chunk.choices.first?.delta.content {
        print(content, terminator: "")
    }
}
```

### Function Calling

```swift
// Define a function
let weatherTool = FunctionBuilder(
    name: "get_weather",
    description: "Get the current weather"
)
.addStringParameter("location", description: "City name", required: true)
.buildTool()

// Make request with tools
let response = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .chat,
        messages: [.user("What's the weather in London?")],
        tools: [weatherTool],
        toolChoice: .auto
    )
)

// Handle tool calls
if let toolCalls = response.choices.first?.message.toolCalls {
    for call in toolCalls {
        print("Function: \(call.function.name)")
        print("Arguments: \(call.function.arguments)")
    }
}
```

### JSON Mode

```swift
let response = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .chat,
        messages: [.user("List 3 colors in JSON format")],
        responseFormat: ResponseFormat(type: .jsonObject)
    )
)
```

### Reasoning Model

```swift
let response = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .reasoner,
        messages: [.user("Solve: If a train travels 120km in 2 hours, what is its average speed?")]
    )
)

// Access reasoning process
if let reasoning = response.choices.first?.message.reasoningContent {
    print("Reasoning: \(reasoning)")
}
print("Answer: \(response.choices.first?.message.content ?? "")")
```

## CLI Usage

The package includes a comprehensive CLI tool for testing all SDK features:

```bash
# Install the CLI
swift build -c release
cp .build/release/deepseek-cli /usr/local/bin/

# Set your API key
export DEEPSEEK_API_KEY="your-api-key"

# Basic chat
deepseek-cli chat "Hello, how are you?"

# Streaming
deepseek-cli stream "Tell me a joke" --show-reasoning

# Function calling
deepseek-cli function-call "What's the weather in Paris?" --auto

# JSON mode
deepseek-cli json-mode "Generate a user profile" --pretty

# Reasoning model
deepseek-cli reasoning "Explain quantum computing" --show-tokens

# Check balance
deepseek-cli balance --detailed

# List models
deepseek-cli models --verbose
```

## API Documentation

Full API documentation is available via DocC. To generate and view:

```bash
swift package generate-documentation
swift package preview-documentation
```

## Testing

Run the test suite:

```bash
swift test
```

Run tests with coverage:

```bash
swift test --enable-code-coverage
```

## Docker Support

Build and run in Docker:

```bash
# Build image
docker build -t deepseek-kit .

# Run tests
docker run --rm deepseek-kit swift test

# Run CLI
docker run --rm -e DEEPSEEK_API_KEY="your-key" deepseek-kit deepseek-cli chat "Hello"
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

DeepSeekKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

This SDK is not officially affiliated with DeepSeek. It's an independent implementation based on their public API documentation.