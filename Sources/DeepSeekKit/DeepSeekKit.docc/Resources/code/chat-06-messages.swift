import DeepSeekKit

// Different ways to create messages
let userMessage = ChatMessage.user("What's the weather like?")
let assistantMessage = ChatMessage.assistant("I'd be happy to help with weather information.")
let systemMessage = ChatMessage.system("You are a helpful weather assistant.")

// Messages have roles and content
print(userMessage.role)     // "user"
print(userMessage.content)  // "What's the weather like?"

// You can also create messages with the full initializer
let customMessage = ChatMessage(
    role: .user,
    content: "Tell me about Swift programming"
)