# DeepSeekKit

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-Apple%20%7C%20Linux-blue.svg)](https://swift.org)
[![CI](https://github.com/marcusziade/DeepSeekKit/actions/workflows/ci.yml/badge.svg)](https://github.com/marcusziade/DeepSeekKit/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/Documentation-DocC-orange)](https://marcusziade.github.io/DeepSeekKit/)

Swift SDK for the DeepSeek API with streaming, function calling, and reasoning model support.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/marcusziade/DeepSeekKit", from: "1.0.0")
]
```

## Quick Start

```swift
import DeepSeekKit

let client = DeepSeekClient(apiKey: "your-api-key")

// Chat
let response = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .chat,
        messages: [.user("What is the capital of France?")]
    )
)

// Streaming
for try await chunk in client.chat.createStreamingCompletion(request) {
    print(chunk.choices.first?.delta.content ?? "", terminator: "")
}

// Function calling
let weatherTool = FunctionBuilder(
    name: "get_weather",
    description: "Get the current weather"
)
.addStringParameter("location", description: "City name", required: true)
.buildTool()

// Reasoning model
let reasoning = try await client.chat.createCompletion(
    ChatCompletionRequest(
        model: .reasoner,
        messages: [.user("Solve: 2 + 2 * 3")]
    )
)
```

## Features

- 🚀 Native streaming on all platforms
- 🛠 Function calling for AI agents
- 🧠 Reasoning model with step-by-step explanations
- 📱 All Apple platforms + Linux
- 📦 Zero dependencies
- 🔧 Type-safe API

## CLI

```bash
# Install
swift build -c release
cp .build/release/deepseek-cli /usr/local/bin/

# Use
export DEEPSEEK_API_KEY="your-key"
deepseek-cli chat "Hello!"
deepseek-cli stream "Tell me a story" --show-reasoning
deepseek-cli balance
```

### Docker

```bash
# Build and run
docker build -t deepseek-kit .
docker run --rm -e DEEPSEEK_API_KEY="your-key" deepseek-kit chat "Hello from Docker!"
```

## Documentation

[Interactive tutorials and API documentation →](https://marcusziade.github.io/DeepSeekKit/)

## License

MIT