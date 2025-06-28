import SwiftUI
import DeepSeekKit
import Combine

// Weather Service Implementation
protocol WeatherServiceProtocol {
    func fetchCurrentWeather(for location: String, units: String) async throws -> WeatherData
    func fetchForecast(for location: String, days: Int) async throws -> [DayForecast]
    func fetchAlerts(for location: String) async throws -> [WeatherAlert]
    func fetchHistoricalData(for location: String, date: Date) async throws -> HistoricalWeather
}

// MARK: - Data Models

struct WeatherData: Codable {
    let location: Location
    let current: CurrentConditions
    let units: Units
    
    struct Location: Codable {
        let name: String
        let region: String
        let country: String
        let latitude: Double
        let longitude: Double
        let timezone: String
    }
    
    struct CurrentConditions: Codable {
        let temperature: Double
        let feelsLike: Double
        let condition: String
        let conditionCode: Int
        let humidity: Int
        let windSpeed: Double
        let windDirection: String
        let windDegree: Int
        let pressure: Double
        let visibility: Double
        let uvIndex: Double
        let cloudCover: Int
        let precipitation: Double
        let lastUpdated: Date
    }
    
    struct Units: Codable {
        let temperature: String
        let speed: String
        let pressure: String
        let distance: String
    }
}

struct DayForecast: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let maxTemp: Double
    let minTemp: Double
    let avgTemp: Double
    let condition: String
    let conditionCode: Int
    let precipitationChance: Int
    let precipitationAmount: Double
    let humidity: Int
    let windSpeed: Double
    let uvIndex: Double
    let sunrise: String
    let sunset: String
    let moonPhase: String
    let hourly: [HourlyForecast]?
}

struct HourlyForecast: Codable {
    let time: Date
    let temperature: Double
    let condition: String
    let precipitationChance: Int
    let windSpeed: Double
    let humidity: Int
}

struct WeatherAlert: Codable, Identifiable {
    let id: String
    let severity: AlertSeverity
    let headline: String
    let description: String
    let instruction: String?
    let areas: [String]
    let effective: Date
    let expires: Date?
    let sender: String
    
    enum AlertSeverity: String, Codable {
        case minor, moderate, severe, extreme
        
        var color: Color {
            switch self {
            case .minor: return .yellow
            case .moderate: return .orange
            case .severe: return .red
            case .extreme: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .minor: return "exclamationmark.triangle"
            case .moderate: return "exclamationmark.triangle.fill"
            case .severe: return "exclamationmark.octagon"
            case .extreme: return "exclamationmark.octagon.fill"
            }
        }
    }
}

struct HistoricalWeather: Codable {
    let date: Date
    let location: String
    let high: Double
    let low: Double
    let avgTemp: Double
    let condition: String
    let precipitation: Double
    let humidity: Int
    let windSpeed: Double
}

// MARK: - Weather Service Implementation

class WeatherService: WeatherServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.weather.example.com/v1"
    private let session: URLSession
    private let cache = WeatherCache()
    
    init(apiKey: String) {
        self.apiKey = apiKey
        
        // Configure URLSession with caching
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,  // 10 MB
            diskCapacity: 50 * 1024 * 1024,     // 50 MB
            diskPath: "weather_cache"
        )
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Current Weather
    
    func fetchCurrentWeather(for location: String, units: String = "imperial") async throws -> WeatherData {
        // Check cache first
        if let cached = cache.getCachedWeather(for: location) {
            return cached
        }
        
        // Build URL
        var components = URLComponents(string: "\(baseURL)/current")!
        components.queryItems = [
            URLQueryItem(name: "q", value: location),
            URLQueryItem(name: "units", value: units),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        // Fetch data
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.invalidResponse
        }
        
        // Decode response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let weatherData = try decoder.decode(WeatherData.self, from: data)
        
        // Cache the result
        cache.cacheWeather(weatherData, for: location)
        
        return weatherData
    }
    
    // MARK: - Forecast
    
    func fetchForecast(for location: String, days: Int = 3) async throws -> [DayForecast] {
        var components = URLComponents(string: "\(baseURL)/forecast")!
        components.queryItems = [
            URLQueryItem(name: "q", value: location),
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([DayForecast].self, from: data)
    }
    
    // MARK: - Alerts
    
    func fetchAlerts(for location: String) async throws -> [WeatherAlert] {
        var components = URLComponents(string: "\(baseURL)/alerts")!
        components.queryItems = [
            URLQueryItem(name: "q", value: location),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WeatherAlert].self, from: data)
    }
    
    // MARK: - Historical Data
    
    func fetchHistoricalData(for location: String, date: Date) async throws -> HistoricalWeather {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        var components = URLComponents(string: "\(baseURL)/history")!
        components.queryItems = [
            URLQueryItem(name: "q", value: location),
            URLQueryItem(name: "date", value: dateString),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HistoricalWeather.self, from: data)
    }
}

// MARK: - Weather Cache

class WeatherCache {
    private var cache: [String: (data: WeatherData, timestamp: Date)] = [:]
    private let cacheLifetime: TimeInterval = 600 // 10 minutes
    
    func getCachedWeather(for location: String) -> WeatherData? {
        guard let cached = cache[location] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) < cacheLifetime {
            return cached.data
        } else {
            // Remove expired cache
            cache.removeValue(forKey: location)
            return nil
        }
    }
    
    func cacheWeather(_ weather: WeatherData, for location: String) {
        cache[location] = (weather, Date())
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Errors

enum WeatherError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case networkError(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode weather data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - Mock Weather Service

class MockWeatherService: WeatherServiceProtocol {
    
    func fetchCurrentWeather(for location: String, units: String = "imperial") async throws -> WeatherData {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Return mock data
        return WeatherData(
            location: WeatherData.Location(
                name: location.components(separatedBy: ",").first ?? location,
                region: "CA",
                country: "USA",
                latitude: 37.7749,
                longitude: -122.4194,
                timezone: "America/Los_Angeles"
            ),
            current: WeatherData.CurrentConditions(
                temperature: 72,
                feelsLike: 75,
                condition: "Partly Cloudy",
                conditionCode: 116,
                humidity: 65,
                windSpeed: 12,
                windDirection: "W",
                windDegree: 270,
                pressure: 30.15,
                visibility: 10,
                uvIndex: 6,
                cloudCover: 40,
                precipitation: 0,
                lastUpdated: Date()
            ),
            units: WeatherData.Units(
                temperature: units == "metric" ? "C" : "F",
                speed: units == "metric" ? "km/h" : "mph",
                pressure: units == "metric" ? "mb" : "in",
                distance: units == "metric" ? "km" : "mi"
            )
        )
    }
    
    func fetchForecast(for location: String, days: Int) async throws -> [DayForecast] {
        try await Task.sleep(nanoseconds: 700_000_000)
        
        var forecast: [DayForecast] = []
        
        for day in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: day, to: Date())!
            
            forecast.append(DayForecast(
                date: date,
                maxTemp: Double.random(in: 70...85),
                minTemp: Double.random(in: 55...70),
                avgTemp: Double.random(in: 65...75),
                condition: ["Sunny", "Partly Cloudy", "Cloudy", "Light Rain"].randomElement()!,
                conditionCode: Int.random(in: 113...302),
                precipitationChance: Int.random(in: 0...100),
                precipitationAmount: Double.random(in: 0...2),
                humidity: Int.random(in: 50...80),
                windSpeed: Double.random(in: 5...20),
                uvIndex: Double.random(in: 1...10),
                sunrise: "6:30 AM",
                sunset: "7:45 PM",
                moonPhase: "Waxing Crescent",
                hourly: nil
            ))
        }
        
        return forecast
    }
    
    func fetchAlerts(for location: String) async throws -> [WeatherAlert] {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Return empty array for most locations
        if location.contains("Florida") {
            return [
                WeatherAlert(
                    id: "ALERT123",
                    severity: .moderate,
                    headline: "Heat Advisory",
                    description: "High temperatures expected. Stay hydrated.",
                    instruction: "Limit outdoor activities during peak hours.",
                    areas: ["Miami-Dade", "Broward"],
                    effective: Date(),
                    expires: Date().addingTimeInterval(86400),
                    sender: "National Weather Service"
                )
            ]
        }
        
        return []
    }
    
    func fetchHistoricalData(for location: String, date: Date) async throws -> HistoricalWeather {
        try await Task.sleep(nanoseconds: 600_000_000)
        
        return HistoricalWeather(
            date: date,
            location: location,
            high: Double.random(in: 70...90),
            low: Double.random(in: 50...70),
            avgTemp: Double.random(in: 60...80),
            condition: "Partly Cloudy",
            precipitation: Double.random(in: 0...2),
            humidity: Int.random(in: 40...80),
            windSpeed: Double.random(in: 5...20)
        )
    }
}

// MARK: - Service Manager

class WeatherServiceManager: ObservableObject {
    @Published var currentWeather: WeatherData?
    @Published var forecast: [DayForecast] = []
    @Published var alerts: [WeatherAlert] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let service: WeatherServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(service: WeatherServiceProtocol = MockWeatherService()) {
        self.service = service
    }
    
    @MainActor
    func loadWeather(for location: String) async {
        isLoading = true
        error = nil
        
        do {
            // Fetch all data in parallel
            async let weatherTask = service.fetchCurrentWeather(for: location, units: "imperial")
            async let forecastTask = service.fetchForecast(for: location, days: 5)
            async let alertsTask = service.fetchAlerts(for: location)
            
            let (weather, forecast, alerts) = try await (weatherTask, forecastTask, alertsTask)
            
            self.currentWeather = weather
            self.forecast = forecast
            self.alerts = alerts
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}