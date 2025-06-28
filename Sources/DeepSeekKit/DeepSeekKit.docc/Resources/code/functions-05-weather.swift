import SwiftUI
import DeepSeekKit
import CoreLocation

// Weather-related function definitions
struct WeatherFunctions {
    
    // MARK: - Function Tool Definitions
    
    static func createWeatherTools() -> [ChatCompletionRequest.Tool] {
        [
            // Current weather tool
            FunctionBuilder()
                .withName("get_current_weather")
                .withDescription("Get the current weather conditions for a specific location")
                .addParameter(
                    "location",
                    type: .string,
                    description: "The city and state/country, e.g., 'San Francisco, CA' or 'London, UK'",
                    required: true
                )
                .addParameter(
                    "units",
                    type: .string,
                    description: "Temperature units",
                    required: false,
                    enumValues: ["celsius", "fahrenheit", "kelvin"],
                    defaultValue: "fahrenheit"
                )
                .build(),
            
            // Weather forecast tool
            FunctionBuilder()
                .withName("get_weather_forecast")
                .withDescription("Get weather forecast for the next few days")
                .addParameter(
                    "location",
                    type: .string,
                    description: "The city and state/country",
                    required: true
                )
                .addParameter(
                    "days",
                    type: .integer,
                    description: "Number of days to forecast (1-7)",
                    required: false,
                    defaultValue: 3
                )
                .addParameter(
                    "include_hourly",
                    type: .boolean,
                    description: "Include hourly forecast",
                    required: false,
                    defaultValue: false
                )
                .build(),
            
            // Weather alerts tool
            FunctionBuilder()
                .withName("get_weather_alerts")
                .withDescription("Get active weather alerts for a location")
                .addParameter(
                    "location",
                    type: .string,
                    description: "The city and state/country",
                    required: true
                )
                .addParameter(
                    "severity",
                    type: .string,
                    description: "Minimum alert severity to include",
                    required: false,
                    enumValues: ["advisory", "watch", "warning", "emergency"],
                    defaultValue: "advisory"
                )
                .build(),
            
            // Historical weather tool
            FunctionBuilder()
                .withName("get_historical_weather")
                .withDescription("Get historical weather data for a specific date")
                .addParameter(
                    "location",
                    type: .string,
                    description: "The city and state/country",
                    required: true
                )
                .addParameter(
                    "date",
                    type: .string,
                    description: "Date in YYYY-MM-DD format",
                    required: true
                )
                .build(),
            
            // Weather comparison tool
            FunctionBuilder()
                .withName("compare_weather")
                .withDescription("Compare weather between multiple locations")
                .addArrayParameter(
                    "locations",
                    itemType: .string,
                    description: "List of locations to compare",
                    required: true
                )
                .addParameter(
                    "metric",
                    type: .string,
                    description: "What to compare",
                    required: false,
                    enumValues: ["temperature", "humidity", "precipitation", "all"],
                    defaultValue: "temperature"
                )
                .build()
        ]
    }
    
    // MARK: - Weather Data Models
    
    struct WeatherData {
        let location: String
        let temperature: Double
        let condition: String
        let humidity: Int
        let windSpeed: Double
        let windDirection: String
        let pressure: Double
        let visibility: Double
        let feelsLike: Double
        let units: TemperatureUnit
        
        enum TemperatureUnit: String {
            case celsius, fahrenheit, kelvin
            
            var symbol: String {
                switch self {
                case .celsius: return "°C"
                case .fahrenheit: return "°F"
                case .kelvin: return "K"
                }
            }
        }
        
        var formattedTemperature: String {
            "\(Int(temperature))\(units.symbol)"
        }
        
        var icon: String {
            switch condition.lowercased() {
            case let c where c.contains("sun") || c.contains("clear"):
                return "sun.max.fill"
            case let c where c.contains("cloud"):
                return "cloud.fill"
            case let c where c.contains("rain"):
                return "cloud.rain.fill"
            case let c where c.contains("snow"):
                return "cloud.snow.fill"
            case let c where c.contains("storm") || c.contains("thunder"):
                return "cloud.bolt.fill"
            case let c where c.contains("fog") || c.contains("mist"):
                return "cloud.fog.fill"
            default:
                return "cloud"
            }
        }
    }
    
    struct ForecastData {
        let date: Date
        let high: Double
        let low: Double
        let condition: String
        let precipitationChance: Int
        let hourly: [HourlyForecast]?
        
        struct HourlyForecast {
            let hour: Int
            let temperature: Double
            let condition: String
            let precipitationChance: Int
        }
    }
    
    struct WeatherAlert {
        let id: String
        let severity: Severity
        let title: String
        let description: String
        let startTime: Date
        let endTime: Date?
        
        enum Severity: String {
            case advisory, watch, warning, emergency
            
            var color: Color {
                switch self {
                case .advisory: return .blue
                case .watch: return .orange
                case .warning: return .red
                case .emergency: return .purple
                }
            }
        }
    }
}

// MARK: - Weather Assistant Manager

class WeatherAssistantManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentWeather: WeatherFunctions.WeatherData?
    @Published var forecast: [WeatherFunctions.ForecastData] = []
    @Published var alerts: [WeatherFunctions.WeatherAlert] = []
    @Published var isLoading = false
    
    private let client: DeepSeekClient
    private let weatherService = MockWeatherService()
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
        setupSystemMessage()
    }
    
    private func setupSystemMessage() {
        messages.append(Message(
            role: .system,
            content: """
            You are a helpful weather assistant. You can check current weather, 
            forecasts, alerts, and historical data. Always use the available 
            weather functions to get accurate information before answering questions.
            """
        ))
    }
    
    func sendMessage(_ content: String) async {
        messages.append(Message(role: .user, content: content))
        isLoading = true
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: messages,
                tools: WeatherFunctions.createWeatherTools()
            )
            
            let response = try await client.chat.completions(request)
            
            if let message = response.choices.first?.message {
                if let toolCalls = message.toolCalls {
                    // Process function calls
                    for toolCall in toolCalls {
                        let result = await executeWeatherFunction(toolCall)
                        messages.append(Message(
                            role: .function,
                            content: result,
                            name: toolCall.function.name,
                            toolCallId: toolCall.id
                        ))
                    }
                    
                    // Get final response
                    let finalRequest = ChatCompletionRequest(
                        model: .deepSeekChat,
                        messages: messages
                    )
                    
                    let finalResponse = try await client.chat.completions(finalRequest)
                    if let finalMessage = finalResponse.choices.first?.message {
                        messages.append(finalMessage)
                    }
                } else {
                    messages.append(message)
                }
            }
        } catch {
            messages.append(Message(
                role: .assistant,
                content: "I encountered an error: \(error.localizedDescription)"
            ))
        }
        
        isLoading = false
    }
    
    private func executeWeatherFunction(_ toolCall: ChatCompletionResponse.Choice.Message.ToolCall) async -> String {
        let functionName = toolCall.function.name
        
        guard let argumentData = toolCall.function.arguments.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentData) as? [String: Any] else {
            return "Error: Invalid arguments"
        }
        
        switch functionName {
        case "get_current_weather":
            return await weatherService.getCurrentWeather(arguments: arguments)
        case "get_weather_forecast":
            return await weatherService.getWeatherForecast(arguments: arguments)
        case "get_weather_alerts":
            return await weatherService.getWeatherAlerts(arguments: arguments)
        case "get_historical_weather":
            return await weatherService.getHistoricalWeather(arguments: arguments)
        case "compare_weather":
            return await weatherService.compareWeather(arguments: arguments)
        default:
            return "Error: Unknown function"
        }
    }
}

// MARK: - Mock Weather Service

class MockWeatherService {
    
    func getCurrentWeather(arguments: [String: Any]) async -> String {
        guard let location = arguments["location"] as? String else {
            return "Error: Location required"
        }
        
        let units = arguments["units"] as? String ?? "fahrenheit"
        
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Mock data based on location
        let weatherData: [String: (temp: Double, condition: String, humidity: Int)] = [
            "San Francisco, CA": (72, "Partly Cloudy", 65),
            "New York, NY": (68, "Clear", 55),
            "London, UK": (59, "Light Rain", 80),
            "Tokyo, Japan": (77, "Humid", 75),
            "Sydney, Australia": (82, "Sunny", 60)
        ]
        
        if let data = weatherData[location] {
            let temp = convertTemperature(data.temp, to: units)
            return """
            {
                "location": "\(location)",
                "temperature": \(temp),
                "condition": "\(data.condition)",
                "humidity": \(data.humidity),
                "wind_speed": \(Double.random(in: 5...20)),
                "wind_direction": "\(["N", "NE", "E", "SE", "S", "SW", "W", "NW"].randomElement()!)",
                "pressure": \(Double.random(in: 29.8...30.2)),
                "visibility": \(Double.random(in: 5...10)),
                "feels_like": \(temp + Double.random(in: -3...3)),
                "units": "\(units)"
            }
            """
        }
        
        return "Weather data not available for \(location)"
    }
    
    func getWeatherForecast(arguments: [String: Any]) async -> String {
        guard let location = arguments["location"] as? String else {
            return "Error: Location required"
        }
        
        let days = arguments["days"] as? Int ?? 3
        let includeHourly = arguments["include_hourly"] as? Bool ?? false
        
        try? await Task.sleep(nanoseconds: 700_000_000)
        
        var forecast = "{"
        forecast += "\"location\": \"\(location)\","
        forecast += "\"forecast\": ["
        
        for day in 0..<days {
            let date = Date().addingTimeInterval(TimeInterval(day * 86400))
            let high = Double.random(in: 70...85)
            let low = high - Double.random(in: 10...20)
            
            forecast += "{"
            forecast += "\"date\": \"\(ISO8601DateFormatter().string(from: date))\","
            forecast += "\"high\": \(high),"
            forecast += "\"low\": \(low),"
            forecast += "\"condition\": \"\(["Sunny", "Partly Cloudy", "Cloudy", "Light Rain"].randomElement()!)\","
            forecast += "\"precipitation_chance\": \(Int.random(in: 0...100))"
            
            if includeHourly {
                forecast += ",\"hourly\": ["
                for hour in 0..<24 {
                    forecast += "{"
                    forecast += "\"hour\": \(hour),"
                    forecast += "\"temperature\": \(low + (high - low) * sin(Double(hour - 6) * .pi / 18)),"
                    forecast += "\"precipitation_chance\": \(Int.random(in: 0...60))"
                    forecast += "}\(hour < 23 ? "," : "")"
                }
                forecast += "]"
            }
            
            forecast += "}\(day < days - 1 ? "," : "")"
        }
        
        forecast += "]}"
        
        return forecast
    }
    
    func getWeatherAlerts(arguments: [String: Any]) async -> String {
        guard let location = arguments["location"] as? String else {
            return "Error: Location required"
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Mock alerts for certain locations
        if location.contains("Florida") || location.contains("TX") {
            return """
            {
                "location": "\(location)",
                "alerts": [
                    {
                        "id": "ALERT001",
                        "severity": "warning",
                        "title": "Severe Thunderstorm Warning",
                        "description": "Severe thunderstorms expected with potential for damaging winds and hail",
                        "start_time": "\(ISO8601DateFormatter().string(from: Date()))",
                        "end_time": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(7200)))"
                    }
                ]
            }
            """
        }
        
        return """
        {
            "location": "\(location)",
            "alerts": []
        }
        """
    }
    
    func getHistoricalWeather(arguments: [String: Any]) async -> String {
        guard let location = arguments["location"] as? String,
              let dateString = arguments["date"] as? String else {
            return "Error: Location and date required"
        }
        
        try? await Task.sleep(nanoseconds: 600_000_000)
        
        // Mock historical data
        let temp = Double.random(in: 50...90)
        
        return """
        {
            "location": "\(location)",
            "date": "\(dateString)",
            "high": \(temp + 10),
            "low": \(temp - 10),
            "average": \(temp),
            "condition": "Partly Cloudy",
            "precipitation": \(Double.random(in: 0...2))
        }
        """
    }
    
    func compareWeather(arguments: [String: Any]) async -> String {
        guard let locations = arguments["locations"] as? [String] else {
            return "Error: Locations array required"
        }
        
        let metric = arguments["metric"] as? String ?? "temperature"
        
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        var comparison = "{"
        comparison += "\"metric\": \"\(metric)\","
        comparison += "\"data\": ["
        
        for (index, location) in locations.enumerated() {
            comparison += "{"
            comparison += "\"location\": \"\(location)\","
            
            switch metric {
            case "temperature":
                comparison += "\"value\": \(Double.random(in: 60...85))"
            case "humidity":
                comparison += "\"value\": \(Int.random(in: 40...90))"
            case "precipitation":
                comparison += "\"value\": \(Double.random(in: 0...5))"
            default:
                comparison += "\"temperature\": \(Double.random(in: 60...85)),"
                comparison += "\"humidity\": \(Int.random(in: 40...90)),"
                comparison += "\"precipitation\": \(Double.random(in: 0...5))"
            }
            
            comparison += "}\(index < locations.count - 1 ? "," : "")"
        }
        
        comparison += "]}"
        
        return comparison
    }
    
    private func convertTemperature(_ temp: Double, to unit: String) -> Double {
        switch unit {
        case "celsius":
            return (temp - 32) * 5/9
        case "kelvin":
            return (temp - 32) * 5/9 + 273.15
        default:
            return temp
        }
    }
}