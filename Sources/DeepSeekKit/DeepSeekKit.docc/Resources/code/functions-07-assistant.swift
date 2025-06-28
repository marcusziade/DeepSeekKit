import SwiftUI
import DeepSeekKit

// Weather Assistant View with Function Handling
struct WeatherAssistantView: View {
    @StateObject private var assistant: WeatherAssistant
    @State private var inputText = ""
    @State private var isExpanded = true
    @FocusState private var isInputFocused: Bool
    
    init(apiKey: String) {
        _assistant = StateObject(wrappedValue: WeatherAssistant(apiKey: apiKey))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            WeatherAssistantHeader(
                isExpanded: $isExpanded,
                location: assistant.currentLocation
            )
            
            if isExpanded {
                // Current weather card
                if let weather = assistant.currentWeather {
                    CurrentWeatherCard(weather: weather)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
                
                // Alerts
                if !assistant.alerts.isEmpty {
                    WeatherAlertsView(alerts: assistant.alerts)
                }
                
                Divider()
                
                // Chat interface
                ChatInterface(
                    messages: assistant.messages,
                    isLoading: assistant.isProcessing
                )
                
                // Input area
                InputArea(
                    text: $inputText,
                    isLoading: assistant.isProcessing,
                    onSend: sendMessage
                )
                .focused($isInputFocused)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
        .animation(.spring(), value: isExpanded)
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        inputText = ""
        isInputFocused = false
        
        Task {
            await assistant.processMessage(message)
        }
    }
}

// MARK: - Weather Assistant Logic

class WeatherAssistant: ObservableObject {
    @Published var messages: [DisplayMessage] = []
    @Published var currentWeather: WeatherData?
    @Published var forecast: [DayForecast] = []
    @Published var alerts: [WeatherAlert] = []
    @Published var currentLocation: String = "Not set"
    @Published var isProcessing = false
    
    private let client: DeepSeekClient
    private let weatherService: WeatherServiceProtocol
    private var conversationMessages: [Message] = []
    
    struct DisplayMessage: Identifiable {
        let id = UUID()
        let role: MessageRole
        let content: String
        let timestamp: Date
        let functionCall: FunctionCallInfo?
        
        struct FunctionCallInfo {
            let name: String
            let status: CallStatus
            
            enum CallStatus {
                case pending
                case executing
                case completed
                case failed(String)
            }
        }
    }
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
        self.weatherService = MockWeatherService()
        
        setupAssistant()
    }
    
    private func setupAssistant() {
        let systemMessage = Message(
            role: .system,
            content: """
            You are a friendly and helpful weather assistant. You can:
            - Check current weather conditions
            - Provide weather forecasts
            - Alert users about severe weather
            - Compare weather between locations
            - Give weather-based recommendations
            
            Always use the weather functions to get real-time data before answering.
            Be conversational and helpful. If users ask about activities, suggest 
            weather-appropriate options.
            """
        )
        
        conversationMessages = [systemMessage]
        
        // Add welcome message
        messages.append(DisplayMessage(
            role: .assistant,
            content: "Hello! I'm your weather assistant. I can help you check current conditions, forecasts, and weather alerts. What location would you like to know about?",
            timestamp: Date(),
            functionCall: nil
        ))
    }
    
    @MainActor
    func processMessage(_ content: String) async {
        // Add user message
        let userMessage = Message(role: .user, content: content)
        conversationMessages.append(userMessage)
        messages.append(DisplayMessage(
            role: .user,
            content: content,
            timestamp: Date(),
            functionCall: nil
        ))
        
        isProcessing = true
        
        do {
            // Create request with weather tools
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: conversationMessages,
                tools: WeatherFunctions.createWeatherTools(),
                temperature: 0.7
            )
            
            let response = try await client.chat.completions(request)
            
            if let message = response.choices.first?.message {
                await handleResponse(message)
            }
        } catch {
            messages.append(DisplayMessage(
                role: .assistant,
                content: "I encountered an error: \(error.localizedDescription)",
                timestamp: Date(),
                functionCall: nil
            ))
        }
        
        isProcessing = false
    }
    
    @MainActor
    private func handleResponse(_ message: Message) async {
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            // Show function call indicator
            for toolCall in toolCalls {
                messages.append(DisplayMessage(
                    role: .assistant,
                    content: "Checking \(formatFunctionName(toolCall.function.name))...",
                    timestamp: Date(),
                    functionCall: DisplayMessage.FunctionCallInfo(
                        name: toolCall.function.name,
                        status: .executing
                    )
                ))
            }
            
            // Execute function calls
            var functionResults: [(String, String, String)] = [] // (id, name, result)
            
            for toolCall in toolCalls {
                let result = await executeFunctionCall(toolCall)
                functionResults.append((toolCall.id, toolCall.function.name, result))
                
                // Add function result to conversation
                conversationMessages.append(Message(
                    role: .function,
                    content: result,
                    name: toolCall.function.name,
                    toolCallId: toolCall.id
                ))
            }
            
            // Get final response with function results
            let finalRequest = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: conversationMessages
            )
            
            let finalResponse = try? await client.chat.completions(finalRequest)
            
            if let finalMessage = finalResponse?.choices.first?.message {
                conversationMessages.append(finalMessage)
                messages.append(DisplayMessage(
                    role: .assistant,
                    content: finalMessage.content,
                    timestamp: Date(),
                    functionCall: nil
                ))
            }
        } else {
            // Regular message without function calls
            conversationMessages.append(message)
            messages.append(DisplayMessage(
                role: .assistant,
                content: message.content,
                timestamp: Date(),
                functionCall: nil
            ))
        }
    }
    
    private func executeFunctionCall(_ toolCall: ChatCompletionResponse.Choice.Message.ToolCall) async -> String {
        let functionName = toolCall.function.name
        
        guard let argumentData = toolCall.function.arguments.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentData) as? [String: Any] else {
            return """
            {"error": "Invalid function arguments"}
            """
        }
        
        switch functionName {
        case "get_current_weather":
            return await executeGetCurrentWeather(arguments)
        case "get_weather_forecast":
            return await executeGetWeatherForecast(arguments)
        case "get_weather_alerts":
            return await executeGetWeatherAlerts(arguments)
        case "compare_weather":
            return await executeCompareWeather(arguments)
        default:
            return """
            {"error": "Unknown function: \(functionName)"}
            """
        }
    }
    
    private func executeGetCurrentWeather(_ arguments: [String: Any]) async -> String {
        guard let location = arguments["location"] as? String else {
            return """
            {"error": "Location parameter required"}
            """
        }
        
        let units = arguments["units"] as? String ?? "fahrenheit"
        currentLocation = location
        
        do {
            let weather = try await weatherService.fetchCurrentWeather(
                for: location,
                units: units == "celsius" ? "metric" : "imperial"
            )
            
            await MainActor.run {
                self.currentWeather = weather
            }
            
            // Return structured JSON response
            return """
            {
                "location": "\(weather.location.name), \(weather.location.region)",
                "temperature": \(weather.current.temperature),
                "feels_like": \(weather.current.feelsLike),
                "condition": "\(weather.current.condition)",
                "humidity": \(weather.current.humidity),
                "wind_speed": \(weather.current.windSpeed),
                "wind_direction": "\(weather.current.windDirection)",
                "pressure": \(weather.current.pressure),
                "visibility": \(weather.current.visibility),
                "uv_index": \(weather.current.uvIndex),
                "units": "\(units)"
            }
            """
        } catch {
            return """
            {"error": "\(error.localizedDescription)"}
            """
        }
    }
    
    private func executeGetWeatherForecast(_ arguments: [String: Any]) async -> String {
        guard let location = arguments["location"] as? String else {
            return """
            {"error": "Location parameter required"}
            """
        }
        
        let days = arguments["days"] as? Int ?? 3
        
        do {
            let forecastData = try await weatherService.fetchForecast(
                for: location,
                days: days
            )
            
            await MainActor.run {
                self.forecast = forecastData
            }
            
            // Convert to JSON response
            var forecastJSON = "{"
            forecastJSON += "\"location\": \"\(location)\","
            forecastJSON += "\"days\": ["
            
            for (index, day) in forecastData.enumerated() {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                
                forecastJSON += "{"
                forecastJSON += "\"date\": \"\(formatter.string(from: day.date))\","
                forecastJSON += "\"high\": \(day.maxTemp),"
                forecastJSON += "\"low\": \(day.minTemp),"
                forecastJSON += "\"condition\": \"\(day.condition)\","
                forecastJSON += "\"precipitation_chance\": \(day.precipitationChance)"
                forecastJSON += "}"
                
                if index < forecastData.count - 1 {
                    forecastJSON += ","
                }
            }
            
            forecastJSON += "]}"
            
            return forecastJSON
        } catch {
            return """
            {"error": "\(error.localizedDescription)"}
            """
        }
    }
    
    private func executeGetWeatherAlerts(_ arguments: [String: Any]) async -> String {
        guard let location = arguments["location"] as? String else {
            return """
            {"error": "Location parameter required"}
            """
        }
        
        do {
            let alertsData = try await weatherService.fetchAlerts(for: location)
            
            await MainActor.run {
                self.alerts = alertsData
            }
            
            if alertsData.isEmpty {
                return """
                {
                    "location": "\(location)",
                    "alerts": [],
                    "message": "No active weather alerts for this location"
                }
                """
            }
            
            // Convert alerts to JSON
            var alertsJSON = "{"
            alertsJSON += "\"location\": \"\(location)\","
            alertsJSON += "\"alert_count\": \(alertsData.count),"
            alertsJSON += "\"alerts\": ["
            
            for (index, alert) in alertsData.enumerated() {
                alertsJSON += "{"
                alertsJSON += "\"severity\": \"\(alert.severity.rawValue)\","
                alertsJSON += "\"headline\": \"\(alert.headline)\","
                alertsJSON += "\"description\": \"\(alert.description)\""
                alertsJSON += "}"
                
                if index < alertsData.count - 1 {
                    alertsJSON += ","
                }
            }
            
            alertsJSON += "]}"
            
            return alertsJSON
        } catch {
            return """
            {"error": "\(error.localizedDescription)"}
            """
        }
    }
    
    private func executeCompareWeather(_ arguments: [String: Any]) async -> String {
        guard let locations = arguments["locations"] as? [String] else {
            return """
            {"error": "Locations array required"}
            """
        }
        
        var comparisonData: [(String, WeatherData)] = []
        
        // Fetch weather for each location
        for location in locations {
            do {
                let weather = try await weatherService.fetchCurrentWeather(
                    for: location,
                    units: "imperial"
                )
                comparisonData.append((location, weather))
            } catch {
                // Skip failed locations
                continue
            }
        }
        
        // Build comparison JSON
        var json = "{"
        json += "\"locations\": ["
        
        for (index, (location, weather)) in comparisonData.enumerated() {
            json += "{"
            json += "\"location\": \"\(location)\","
            json += "\"temperature\": \(weather.current.temperature),"
            json += "\"condition\": \"\(weather.current.condition)\","
            json += "\"humidity\": \(weather.current.humidity),"
            json += "\"wind_speed\": \(weather.current.windSpeed)"
            json += "}"
            
            if index < comparisonData.count - 1 {
                json += ","
            }
        }
        
        json += "]}"
        
        return json
    }
    
    private func formatFunctionName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

// MARK: - UI Components

struct WeatherAssistantHeader: View {
    @Binding var isExpanded: Bool
    let location: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Weather Assistant")
                    .font(.headline)
                
                Text(location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

struct CurrentWeatherCard: View {
    let weather: WeatherData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(weather.location.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(weather.current.condition)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label("\(Int(weather.current.humidity))%", systemImage: "humidity")
                    Label("\(Int(weather.current.windSpeed)) mph", systemImage: "wind")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(weather.current.temperature))°")
                    .font(.system(size: 48, weight: .light))
                
                Text("Feels like \(Int(weather.current.feelsLike))°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct WeatherAlertsView: View {
    let alerts: [WeatherAlert]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(alerts) { alert in
                HStack {
                    Image(systemName: alert.severity.icon)
                        .foregroundColor(alert.severity.color)
                    
                    Text(alert.headline)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(alert.severity.color.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}

struct ChatInterface: View {
    let messages: [WeatherAssistant.DisplayMessage]
    let isLoading: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if isLoading {
                        TypingIndicator()
                            .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id ?? "loading", anchor: .bottom)
                }
            }
        }
    }
}

struct ChatMessageBubble: View {
    let message: WeatherAssistant.DisplayMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let functionCall = message.functionCall {
                    FunctionCallIndicator(functionCall: functionCall)
                }
                
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.role == .user ? Color.blue : Color(.secondarySystemBackground))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
            }
            
            if message.role != .user {
                Spacer()
            }
        }
    }
}

struct FunctionCallIndicator: View {
    let functionCall: WeatherAssistant.DisplayMessage.FunctionCallInfo
    
    var body: some View {
        HStack(spacing: 4) {
            switch functionCall.status {
            case .pending:
                ProgressView()
                    .scaleEffect(0.7)
            case .executing:
                Image(systemName: "function")
                    .foregroundColor(.orange)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
            
            Text(functionCall.name.replacingOccurrences(of: "_", with: " "))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct InputArea: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack {
            TextField("Ask about weather...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isLoading)
                .onSubmit(onSend)
            
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(text.isEmpty || isLoading ? .gray : .blue)
            }
            .disabled(text.isEmpty || isLoading)
        }
        .padding()
    }
}

struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -10
        }
    }
}