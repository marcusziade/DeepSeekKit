import SwiftUI
import DeepSeekKit

// Creating user-friendly error messages
struct UserFriendlyErrorsView: View {
    @StateObject private var errorTranslator = ErrorMessageTranslator()
    @State private var selectedError: ErrorScenario?
    @State private var customizationLevel: CustomizationLevel = .standard
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("User-Friendly Error Messages")
                    .font(.largeTitle)
                    .bold()
                
                // Customization level selector
                CustomizationSelector(level: $customizationLevel)
                
                // Error scenario grid
                ErrorScenarioGrid(
                    selectedError: $selectedError,
                    translator: errorTranslator
                )
                
                // Selected error display
                if let error = selectedError {
                    ErrorMessageDisplay(
                        error: error,
                        level: customizationLevel,
                        translator: errorTranslator
                    )
                }
                
                // Message templates
                MessageTemplatesView()
                
                // Localization examples
                LocalizationExamplesView(translator: errorTranslator)
            }
            .padding()
        }
    }
}

// Customization levels
enum CustomizationLevel: String, CaseIterable {
    case technical = "Technical"
    case standard = "Standard"
    case friendly = "Friendly"
    case simplified = "Simplified"
    
    var description: String {
        switch self {
        case .technical:
            return "Full technical details for developers"
        case .standard:
            return "Balanced information for most users"
        case .friendly:
            return "Conversational tone with guidance"
        case .simplified:
            return "Minimal details, focus on action"
        }
    }
}

// Error scenarios
struct ErrorScenario: Identifiable {
    let id = UUID()
    let error: DeepSeekError
    let context: String
    let icon: String
    let color: Color
    
    static let scenarios: [ErrorScenario] = [
        ErrorScenario(
            error: .authenticationError,
            context: "User trying to send first message",
            icon: "lock.fill",
            color: .red
        ),
        ErrorScenario(
            error: .rateLimitExceeded,
            context: "Heavy usage during peak hours",
            icon: "hourglass",
            color: .orange
        ),
        ErrorScenario(
            error: .networkError(URLError(.notConnectedToInternet)),
            context: "Mobile user with poor connection",
            icon: "wifi.exclamationmark",
            color: .blue
        ),
        ErrorScenario(
            error: .apiError(statusCode: 500, message: "Internal server error"),
            context: "Server maintenance period",
            icon: "server.rack",
            color: .purple
        ),
        ErrorScenario(
            error: .invalidRequest("Model 'gpt-5' does not exist"),
            context: "User selected wrong model",
            icon: "exclamationmark.square",
            color: .yellow
        ),
        ErrorScenario(
            error: .streamError("Connection reset during streaming"),
            context: "Long streaming response interrupted",
            icon: "dot.radiowaves.left.and.right",
            color: .indigo
        )
    ]
}

// Error message translator
@MainActor
class ErrorMessageTranslator: ObservableObject {
    @Published var currentLanguage = "en"
    @Published var enableEmoji = true
    @Published var showTechnicalDetails = false
    
    func translate(
        error: DeepSeekError,
        level: CustomizationLevel,
        context: String
    ) -> TranslatedMessage {
        let baseMessage = getBaseMessage(for: error, level: level)
        let suggestion = getSuggestion(for: error, level: level, context: context)
        let technicalDetails = getTechnicalDetails(for: error)
        
        return TranslatedMessage(
            title: baseMessage.title,
            message: baseMessage.message,
            suggestion: suggestion,
            technicalDetails: showTechnicalDetails ? technicalDetails : nil,
            icon: getIcon(for: error),
            actionButtons: getActionButtons(for: error)
        )
    }
    
    struct TranslatedMessage {
        let title: String
        let message: String
        let suggestion: String
        let technicalDetails: String?
        let icon: String
        let actionButtons: [ActionButton]
    }
    
    struct ActionButton: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let action: () -> Void
    }
    
    private func getBaseMessage(
        for error: DeepSeekError,
        level: CustomizationLevel
    ) -> (title: String, message: String) {
        switch (error, level) {
        case (.authenticationError, .technical):
            return ("Authentication Failed", "API key validation failed with 401 Unauthorized")
            
        case (.authenticationError, .standard):
            return ("Authentication Required", "Your API key is invalid or missing")
            
        case (.authenticationError, .friendly):
            return ("Let's Get You Connected", "It looks like we need to verify your API key")
            
        case (.authenticationError, .simplified):
            return ("Access Denied", "Please check your API key")
            
        case (.rateLimitExceeded, .technical):
            return ("Rate Limit Exceeded", "429 Too Many Requests - Rate limit quota exhausted")
            
        case (.rateLimitExceeded, .standard):
            return ("Too Many Requests", "You've exceeded the rate limit for API calls")
            
        case (.rateLimitExceeded, .friendly):
            return ("Slow Down a Bit", "You're sending requests too quickly. Let's take a brief pause")
            
        case (.rateLimitExceeded, .simplified):
            return ("Please Wait", "Too many requests. Try again in a minute")
            
        case (.networkError, .technical):
            return ("Network Error", "URLError: The Internet connection appears to be offline")
            
        case (.networkError, .standard):
            return ("Connection Problem", "Unable to connect to DeepSeek servers")
            
        case (.networkError, .friendly):
            return ("Connection Trouble", "We're having trouble reaching the server. Check your internet?")
            
        case (.networkError, .simplified):
            return ("No Connection", "Please check your internet")
            
        default:
            return getGenericMessage(level: level)
        }
    }
    
    private func getSuggestion(
        for error: DeepSeekError,
        level: CustomizationLevel,
        context: String
    ) -> String {
        if enableEmoji {
            return getEmojiSuggestion(for: error, level: level)
        } else {
            return getTextSuggestion(for: error, level: level)
        }
    }
    
    private func getEmojiSuggestion(
        for error: DeepSeekError,
        level: CustomizationLevel
    ) -> String {
        switch (error, level) {
        case (.authenticationError, _):
            return "🔑 Add your API key in Settings"
            
        case (.rateLimitExceeded, .friendly):
            return "☕ Perfect time for a coffee break! We'll be ready in about a minute"
            
        case (.rateLimitExceeded, _):
            return "⏱️ Wait 60 seconds before trying again"
            
        case (.networkError, .friendly):
            return "📡 Try moving to a better spot or switching to Wi-Fi"
            
        case (.networkError, _):
            return "🌐 Check your internet connection"
            
        default:
            return "🔄 Try again or contact support"
        }
    }
    
    private func getTextSuggestion(
        for error: DeepSeekError,
        level: CustomizationLevel
    ) -> String {
        switch (error, level) {
        case (.authenticationError, _):
            return "Add your API key in Settings"
            
        case (.rateLimitExceeded, _):
            return "Wait 60 seconds before trying again"
            
        case (.networkError, _):
            return "Check your internet connection"
            
        default:
            return "Try again or contact support"
        }
    }
    
    private func getTechnicalDetails(for error: DeepSeekError) -> String {
        switch error {
        case .authenticationError:
            return "HTTP 401 - Missing or invalid Bearer token in Authorization header"
            
        case .rateLimitExceeded:
            return "HTTP 429 - X-RateLimit-Remaining: 0"
            
        case .networkError(let underlyingError):
            return "URLError: \(underlyingError.localizedDescription)\nCode: \((underlyingError as? URLError)?.code.rawValue ?? -1)"
            
        case .apiError(let code, let message):
            return "HTTP \(code)\nResponse: \(message ?? "No message")"
            
        case .invalidRequest(let details):
            return "Request validation failed:\n\(details)"
            
        case .invalidResponse(let details):
            return "Response parsing failed:\n\(details)"
            
        case .streamError(let details):
            return "Stream error:\n\(details)"
        }
    }
    
    private func getIcon(for error: DeepSeekError) -> String {
        switch error {
        case .authenticationError: return "lock.fill"
        case .rateLimitExceeded: return "hourglass"
        case .networkError: return "wifi.exclamationmark"
        case .apiError: return "server.rack"
        case .invalidRequest: return "exclamationmark.square"
        case .invalidResponse: return "questionmark.square"
        case .streamError: return "dot.radiowaves.left.and.right"
        }
    }
    
    private func getActionButtons(for error: DeepSeekError) -> [ActionButton] {
        switch error {
        case .authenticationError:
            return [
                ActionButton(
                    title: "Open Settings",
                    icon: "gear",
                    action: { print("Open settings") }
                ),
                ActionButton(
                    title: "Get API Key",
                    icon: "key",
                    action: { print("Open DeepSeek dashboard") }
                )
            ]
            
        case .rateLimitExceeded:
            return [
                ActionButton(
                    title: "Set Reminder",
                    icon: "alarm",
                    action: { print("Set 1 minute reminder") }
                )
            ]
            
        case .networkError:
            return [
                ActionButton(
                    title: "Network Settings",
                    icon: "wifi",
                    action: { print("Open network settings") }
                ),
                ActionButton(
                    title: "Retry",
                    icon: "arrow.clockwise",
                    action: { print("Retry request") }
                )
            ]
            
        default:
            return [
                ActionButton(
                    title: "Try Again",
                    icon: "arrow.clockwise",
                    action: { print("Retry") }
                )
            ]
        }
    }
    
    private func getGenericMessage(level: CustomizationLevel) -> (String, String) {
        switch level {
        case .technical:
            return ("Error", "An unexpected error occurred")
        case .standard:
            return ("Something Went Wrong", "We encountered an error processing your request")
        case .friendly:
            return ("Oops!", "Something didn't go quite right")
        case .simplified:
            return ("Error", "Please try again")
        }
    }
    
    func localizedMessage(key: String) -> String {
        // Simplified localization
        let localizations: [String: [String: String]] = [
            "en": [
                "error.auth.title": "Authentication Required",
                "error.auth.message": "Please check your API key",
                "error.network.title": "Connection Problem",
                "error.network.message": "Check your internet connection"
            ],
            "es": [
                "error.auth.title": "Autenticación Requerida",
                "error.auth.message": "Por favor verifica tu clave API",
                "error.network.title": "Problema de Conexión",
                "error.network.message": "Verifica tu conexión a internet"
            ],
            "fr": [
                "error.auth.title": "Authentification Requise",
                "error.auth.message": "Veuillez vérifier votre clé API",
                "error.network.title": "Problème de Connexion",
                "error.network.message": "Vérifiez votre connexion internet"
            ]
        ]
        
        return localizations[currentLanguage]?[key] ?? key
    }
}

// UI Components
struct CustomizationSelector: View {
    @Binding var level: CustomizationLevel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Message Customization Level")
                .font(.headline)
            
            Picker("Level", selection: $level) {
                ForEach(CustomizationLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Text(level.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ErrorScenarioGrid: View {
    @Binding var selectedError: ErrorScenario?
    @ObservedObject var translator: ErrorMessageTranslator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Error Scenario")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ErrorScenario.scenarios) { scenario in
                    ErrorScenarioCard(
                        scenario: scenario,
                        isSelected: selectedError?.id == scenario.id,
                        action: { selectedError = scenario }
                    )
                }
            }
        }
    }
}

struct ErrorScenarioCard: View {
    let scenario: ErrorScenario
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: scenario.icon)
                    .font(.title2)
                    .foregroundColor(scenario.color)
                
                Text(errorTitle)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? scenario.color.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? scenario.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    var errorTitle: String {
        switch scenario.error {
        case .authenticationError: return "Auth Error"
        case .rateLimitExceeded: return "Rate Limit"
        case .networkError: return "Network"
        case .apiError: return "API Error"
        case .invalidRequest: return "Invalid Request"
        case .streamError: return "Stream Error"
        default: return "Error"
        }
    }
}

struct ErrorMessageDisplay: View {
    let error: ErrorScenario
    let level: CustomizationLevel
    @ObservedObject var translator: ErrorMessageTranslator
    
    var body: some View {
        let message = translator.translate(
            error: error.error,
            level: level,
            context: error.context
        )
        
        VStack(alignment: .leading, spacing: 16) {
            // Context
            Label(error.context, systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Error message
            ErrorMessageCard(message: message)
            
            // Options
            HStack {
                Toggle("Show Emoji", isOn: $translator.enableEmoji)
                Toggle("Technical Details", isOn: $translator.showTechnicalDetails)
            }
            .font(.caption)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ErrorMessageCard: View {
    let message: ErrorMessageTranslator.TranslatedMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: message.icon)
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text(message.title)
                    .font(.headline)
                
                Spacer()
            }
            
            // Message
            Text(message.message)
                .font(.subheadline)
            
            // Suggestion
            Label(message.suggestion, systemImage: "lightbulb")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            // Technical details
            if let technical = message.technicalDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Technical Details")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(technical)
                        .font(.caption)
                        .fontFamily(.monospaced)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action buttons
            if !message.actionButtons.isEmpty {
                HStack(spacing: 12) {
                    ForEach(message.actionButtons) { button in
                        Button(action: button.action) {
                            Label(button.title, systemImage: button.icon)
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct MessageTemplatesView: View {
    let templates = [
        MessageTemplate(
            name: "Friendly Retry",
            template: "Almost there! {error_type} happened, but don't worry. {suggestion} and we'll be back on track!",
            example: "Almost there! A connection hiccup happened, but don't worry. Check your Wi-Fi and we'll be back on track!"
        ),
        MessageTemplate(
            name: "Technical Brief",
            template: "[{error_code}] {error_message}. Action: {recovery_action}",
            example: "[429] Rate limit exceeded. Action: Retry after 60 seconds"
        ),
        MessageTemplate(
            name: "Conversational",
            template: "Hey, it looks like {problem_description}. How about we {suggested_solution}?",
            example: "Hey, it looks like we're having trouble connecting. How about we check your internet connection?"
        )
    ]
    
    struct MessageTemplate: Identifiable {
        let id = UUID()
        let name: String
        let template: String
        let example: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Message Templates")
                .font(.headline)
            
            ForEach(templates) { template in
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Template: \(template.template)")
                        .font(.caption)
                        .fontFamily(.monospaced)
                        .foregroundColor(.blue)
                    
                    Text("Example: \(template.example)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}

struct LocalizationExamplesView: View {
    @ObservedObject var translator: ErrorMessageTranslator
    let languages = ["en", "es", "fr"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Localization Examples")
                .font(.headline)
            
            Picker("Language", selection: $translator.currentLanguage) {
                ForEach(languages, id: \.self) { lang in
                    Text(languageName(lang)).tag(lang)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack(alignment: .leading, spacing: 8) {
                LocalizedMessageRow(
                    key: "error.auth.title",
                    translator: translator
                )
                
                LocalizedMessageRow(
                    key: "error.auth.message",
                    translator: translator
                )
                
                LocalizedMessageRow(
                    key: "error.network.title",
                    translator: translator
                )
                
                LocalizedMessageRow(
                    key: "error.network.message",
                    translator: translator
                )
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
    
    func languageName(_ code: String) -> String {
        switch code {
        case "en": return "English"
        case "es": return "Español"
        case "fr": return "Français"
        default: return code
        }
    }
}

struct LocalizedMessageRow: View {
    let key: String
    @ObservedObject var translator: ErrorMessageTranslator
    
    var body: some View {
        HStack {
            Text(key)
                .font(.caption)
                .fontFamily(.monospaced)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(translator.localizedMessage(key: key))
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}