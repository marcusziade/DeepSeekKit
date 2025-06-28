import SwiftUI
import DeepSeekKit

// Natural language control for smart home devices
struct NaturalLanguageControl {
    
    // MARK: - Intent Recognition
    
    enum DeviceIntent {
        case turnOn(device: String, room: String?)
        case turnOff(device: String, room: String?)
        case setBrightness(device: String, level: Int, room: String?)
        case setTemperature(value: Double, room: String?)
        case setColor(device: String, color: String, room: String?)
        case lock(device: String)
        case unlock(device: String)
        case playMusic(speaker: String?, genre: String?)
        case setVolume(device: String?, level: Int)
        case activateScene(name: String)
        case query(device: String?, property: String?)
        case createAutomation(trigger: String, action: String)
        case unknown(query: String)
    }
    
    // MARK: - Natural Language Processor
    
    class NLProcessor: ObservableObject {
        @Published var recentIntents: [ProcessedIntent] = []
        @Published var suggestions: [String] = []
        @Published var isProcessing = false
        
        struct ProcessedIntent: Identifiable {
            let id = UUID()
            let originalQuery: String
            let intent: DeviceIntent
            let confidence: Double
            let timestamp: Date
            let alternatives: [DeviceIntent]
        }
        
        private let commonPhrases = [
            // Lighting
            "turn on the lights",
            "turn off all lights",
            "dim the bedroom lights",
            "set living room lights to 50%",
            "make the lights warmer",
            "brighten the kitchen",
            
            // Climate
            "set temperature to 72",
            "make it warmer",
            "turn on the AC",
            "what's the temperature?",
            
            // Entertainment
            "play some music",
            "turn up the volume",
            "pause the music",
            "play jazz in the living room",
            
            // Security
            "lock all doors",
            "is the front door locked?",
            "show me the front camera",
            
            // Scenes
            "good morning",
            "good night",
            "I'm leaving",
            "movie time",
            
            // Complex
            "turn off everything",
            "set all lights to blue",
            "when I get home, turn on the lights"
        ]
        
        init() {
            loadSuggestions()
        }
        
        private func loadSuggestions() {
            suggestions = Array(commonPhrases.shuffled().prefix(5))
        }
        
        func processQuery(_ query: String) -> ProcessedIntent {
            isProcessing = true
            
            let lowercased = query.lowercased()
            let intent = parseIntent(from: lowercased)
            let alternatives = findAlternativeIntents(for: lowercased)
            
            let processed = ProcessedIntent(
                originalQuery: query,
                intent: intent,
                confidence: calculateConfidence(for: intent, query: lowercased),
                timestamp: Date(),
                alternatives: alternatives
            )
            
            recentIntents.insert(processed, at: 0)
            if recentIntents.count > 10 {
                recentIntents.removeLast()
            }
            
            isProcessing = false
            return processed
        }
        
        private func parseIntent(from query: String) -> DeviceIntent {
            // Turn on/off detection
            if query.contains("turn on") || query.contains("switch on") {
                return parseTurnOnIntent(query)
            } else if query.contains("turn off") || query.contains("switch off") {
                return parseTurnOffIntent(query)
            }
            
            // Brightness control
            if query.contains("dim") || query.contains("brightness") || query.contains("%") {
                return parseBrightnessIntent(query)
            }
            
            // Temperature control
            if query.contains("temperature") || query.contains("degrees") || query.contains("warmer") || query.contains("cooler") {
                return parseTemperatureIntent(query)
            }
            
            // Color control
            if containsColor(query) {
                return parseColorIntent(query)
            }
            
            // Lock control
            if query.contains("lock") {
                return parseLockIntent(query)
            } else if query.contains("unlock") {
                return parseUnlockIntent(query)
            }
            
            // Music control
            if query.contains("play") && (query.contains("music") || query.contains("song")) {
                return parseMusicIntent(query)
            }
            
            // Volume control
            if query.contains("volume") {
                return parseVolumeIntent(query)
            }
            
            // Scene activation
            if containsSceneName(query) {
                return parseSceneIntent(query)
            }
            
            // Query intent
            if query.starts(with: "what") || query.starts(with: "is") || query.contains("?") {
                return parseQueryIntent(query)
            }
            
            // Automation creation
            if query.contains("when") || query.contains("if") {
                return parseAutomationIntent(query)
            }
            
            return .unknown(query: query)
        }
        
        // MARK: - Intent Parsers
        
        private func parseTurnOnIntent(_ query: String) -> DeviceIntent {
            let device = extractDevice(from: query) ?? "lights"
            let room = extractRoom(from: query)
            return .turnOn(device: device, room: room)
        }
        
        private func parseTurnOffIntent(_ query: String) -> DeviceIntent {
            let device = extractDevice(from: query) ?? "lights"
            let room = extractRoom(from: query)
            return .turnOff(device: device, room: room)
        }
        
        private func parseBrightnessIntent(_ query: String) -> DeviceIntent {
            let device = extractDevice(from: query) ?? "lights"
            let room = extractRoom(from: query)
            let level = extractPercentage(from: query) ?? 50
            return .setBrightness(device: device, level: level, room: room)
        }
        
        private func parseTemperatureIntent(_ query: String) -> DeviceIntent {
            let room = extractRoom(from: query)
            
            if let degrees = extractNumber(from: query) {
                return .setTemperature(value: Double(degrees), room: room)
            }
            
            // Handle relative changes
            if query.contains("warmer") {
                return .setTemperature(value: 72, room: room) // Default increase
            } else if query.contains("cooler") {
                return .setTemperature(value: 68, room: room) // Default decrease
            }
            
            return .query(device: "thermostat", property: "temperature")
        }
        
        private func parseColorIntent(_ query: String) -> DeviceIntent {
            let device = extractDevice(from: query) ?? "lights"
            let room = extractRoom(from: query)
            let color = extractColor(from: query) ?? "white"
            return .setColor(device: device, color: color, room: room)
        }
        
        private func parseLockIntent(_ query: String) -> DeviceIntent {
            let device = extractLockDevice(from: query) ?? "doors"
            return .lock(device: device)
        }
        
        private func parseUnlockIntent(_ query: String) -> DeviceIntent {
            let device = extractLockDevice(from: query) ?? "door"
            return .unlock(device: device)
        }
        
        private func parseMusicIntent(_ query: String) -> DeviceIntent {
            let speaker = extractSpeaker(from: query)
            let genre = extractMusicGenre(from: query)
            return .playMusic(speaker: speaker, genre: genre)
        }
        
        private func parseVolumeIntent(_ query: String) -> DeviceIntent {
            let device = extractDevice(from: query)
            let level = extractPercentage(from: query) ?? 50
            return .setVolume(device: device, level: level)
        }
        
        private func parseSceneIntent(_ query: String) -> DeviceIntent {
            let scene = extractSceneName(from: query) ?? "unknown"
            return .activateScene(name: scene)
        }
        
        private func parseQueryIntent(_ query: String) -> DeviceIntent {
            let device = extractDevice(from: query)
            let property = extractProperty(from: query)
            return .query(device: device, property: property)
        }
        
        private func parseAutomationIntent(_ query: String) -> DeviceIntent {
            // Simple automation parsing
            let parts = query.split(separator: ",")
            let trigger = String(parts.first ?? "")
            let action = parts.count > 1 ? String(parts[1]) : ""
            return .createAutomation(trigger: trigger, action: action)
        }
        
        // MARK: - Extraction Helpers
        
        private func extractDevice(from query: String) -> String? {
            let devices = ["lights", "light", "lamp", "thermostat", "speaker", "tv", "fan", "plug"]
            return devices.first { query.contains($0) }
        }
        
        private func extractRoom(from query: String) -> String? {
            let rooms = ["living room", "bedroom", "kitchen", "bathroom", "office", "garage", "hallway", "dining room"]
            return rooms.first { query.contains($0) }
        }
        
        private func extractPercentage(from query: String) -> Int? {
            if let range = query.range(of: #"\d+%?"#, options: .regularExpression) {
                let numberString = query[range].replacingOccurrences(of: "%", with: "")
                return Int(numberString)
            }
            
            // Handle words
            if query.contains("half") { return 50 }
            if query.contains("quarter") { return 25 }
            if query.contains("full") || query.contains("max") { return 100 }
            if query.contains("min") { return 10 }
            
            return nil
        }
        
        private func extractNumber(from query: String) -> Int? {
            let pattern = #"\b\d+\b"#
            if let range = query.range(of: pattern, options: .regularExpression) {
                return Int(query[range])
            }
            return nil
        }
        
        private func containsColor(_ query: String) -> Bool {
            let colors = ["red", "green", "blue", "yellow", "orange", "purple", "pink", "white", "warm", "cool"]
            return colors.contains { query.contains($0) }
        }
        
        private func extractColor(from query: String) -> String? {
            let colors = ["red", "green", "blue", "yellow", "orange", "purple", "pink", "white"]
            return colors.first { query.contains($0) }
        }
        
        private func extractLockDevice(from query: String) -> String? {
            let locks = ["front door", "back door", "garage", "door", "doors", "lock", "locks"]
            return locks.first { query.contains($0) }
        }
        
        private func extractSpeaker(from query: String) -> String? {
            return extractRoom(from: query).map { "\($0) speaker" }
        }
        
        private func extractMusicGenre(from query: String) -> String? {
            let genres = ["jazz", "rock", "pop", "classical", "hip hop", "country", "electronic"]
            return genres.first { query.contains($0) }
        }
        
        private func containsSceneName(_ query: String) -> Bool {
            let scenes = ["good morning", "good night", "movie time", "party", "away", "home"]
            return scenes.contains { query.contains($0) }
        }
        
        private func extractSceneName(from query: String) -> String? {
            let scenes = ["good morning", "good night", "movie time", "party", "away", "home"]
            return scenes.first { query.contains($0) }
        }
        
        private func extractProperty(from query: String) -> String? {
            let properties = ["temperature", "brightness", "status", "locked", "playing", "volume"]
            return properties.first { query.contains($0) }
        }
        
        private func calculateConfidence(for intent: DeviceIntent, query: String) -> Double {
            switch intent {
            case .unknown:
                return 0.3
            case .turnOn, .turnOff:
                return query.contains("all") ? 0.9 : 0.85
            case .setBrightness, .setTemperature:
                return 0.9
            case .activateScene:
                return 0.95
            default:
                return 0.8
            }
        }
        
        private func findAlternativeIntents(for query: String) -> [DeviceIntent] {
            // Return up to 2 alternative interpretations
            var alternatives: [DeviceIntent] = []
            
            if query.contains("light") && query.contains("50") {
                alternatives.append(.setBrightness(device: "lights", level: 50, room: nil))
            }
            
            if query.contains("off") && query.contains("everything") {
                alternatives.append(.activateScene(name: "away"))
            }
            
            return alternatives
        }
    }
}

// MARK: - Natural Language UI

struct NaturalLanguageControlView: View {
    @StateObject private var nlProcessor = NaturalLanguageControl.NLProcessor()
    @StateObject private var smartHome = SmartHomeManager()
    @State private var inputText = ""
    @State private var isListening = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Recent intents
            if !nlProcessor.recentIntents.isEmpty {
                RecentIntentsView(intents: nlProcessor.recentIntents)
            }
            
            // Suggestions
            SuggestionsView(suggestions: nlProcessor.suggestions) { suggestion in
                inputText = suggestion
                processInput()
            }
            
            Spacer()
            
            // Input area
            NaturalLanguageInput(
                text: $inputText,
                isListening: $isListening,
                isProcessing: nlProcessor.isProcessing,
                onSubmit: processInput,
                onVoiceInput: startVoiceInput
            )
            .focused($isInputFocused)
        }
        .navigationTitle("Natural Control")
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func processInput() {
        guard !inputText.isEmpty else { return }
        
        let query = inputText
        inputText = ""
        
        let intent = nlProcessor.processQuery(query)
        executeIntent(intent.intent)
    }
    
    private func startVoiceInput() {
        // Implement voice input
        isListening = true
        
        // Simulate voice recognition
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            inputText = "Turn on the living room lights"
            isListening = false
        }
    }
    
    private func executeIntent(_ intent: NaturalLanguageControl.DeviceIntent) {
        Task {
            switch intent {
            case .turnOn(let device, let room):
                await handleTurnOn(device: device, room: room)
                
            case .turnOff(let device, let room):
                await handleTurnOff(device: device, room: room)
                
            case .setBrightness(let device, let level, let room):
                await handleSetBrightness(device: device, level: level, room: room)
                
            case .setTemperature(let value, let room):
                await handleSetTemperature(value: value, room: room)
                
            case .activateScene(let name):
                await handleActivateScene(name: name)
                
            default:
                print("Intent not implemented: \(intent)")
            }
        }
    }
    
    private func handleTurnOn(device: String, room: String?) async {
        let devices = smartHome.devices.filter { dev in
            let matchesType = device == "lights" ? dev.type == .light : true
            let matchesRoom = room != nil ? dev.room == room : true
            return matchesType && matchesRoom
        }
        
        for device in devices {
            _ = await smartHome.controlDevice(deviceId: device.id, action: "turn_on")
        }
    }
    
    private func handleTurnOff(device: String, room: String?) async {
        let devices = smartHome.devices.filter { dev in
            let matchesType = device == "lights" ? dev.type == .light : true
            let matchesRoom = room != nil ? dev.room == room : true
            return matchesType && matchesRoom
        }
        
        for device in devices {
            _ = await smartHome.controlDevice(deviceId: device.id, action: "turn_off")
        }
    }
    
    private func handleSetBrightness(device: String, level: Int, room: String?) async {
        let devices = smartHome.devices.filter { dev in
            dev.type == .light && (room != nil ? dev.room == room : true)
        }
        
        for device in devices {
            _ = await smartHome.controlDevice(deviceId: device.id, action: "set_brightness", value: level)
        }
    }
    
    private func handleSetTemperature(value: Double, room: String?) async {
        let thermostats = smartHome.devices.filter { dev in
            dev.type == .thermostat && (room != nil ? dev.room == room : true)
        }
        
        for thermostat in thermostats {
            _ = await smartHome.controlDevice(deviceId: thermostat.id, action: "set_temperature", value: value)
        }
    }
    
    private func handleActivateScene(name: String) async {
        _ = await smartHome.executeScene(name)
    }
}

// MARK: - UI Components

struct RecentIntentsView: View {
    let intents: [NaturalLanguageControl.NLProcessor.ProcessedIntent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Commands")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(intents) { intent in
                        IntentRow(intent: intent)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
        }
        .background(Color(.systemGray6))
    }
}

struct IntentRow: View {
    let intent: NaturalLanguageControl.NLProcessor.ProcessedIntent
    @State private var showAlternatives = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(intent.originalQuery)
                        .font(.subheadline)
                    
                    Text(describeIntent(intent.intent))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ConfidenceIndicator(confidence: intent.confidence)
                
                if !intent.alternatives.isEmpty {
                    Button(action: { showAlternatives.toggle() }) {
                        Image(systemName: showAlternatives ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
            }
            
            if showAlternatives {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alternative interpretations:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(intent.alternatives.indices, id: \.self) { index in
                        Text("• \(describeIntent(intent.alternatives[index]))")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.leading)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func describeIntent(_ intent: NaturalLanguageControl.DeviceIntent) -> String {
        switch intent {
        case .turnOn(let device, let room):
            return "Turn on \(device)\(room != nil ? " in \(room!)" : "")"
        case .turnOff(let device, let room):
            return "Turn off \(device)\(room != nil ? " in \(room!)" : "")"
        case .setBrightness(let device, let level, let room):
            return "Set \(device) to \(level)%\(room != nil ? " in \(room!)" : "")"
        case .setTemperature(let value, let room):
            return "Set temperature to \(Int(value))°\(room != nil ? " in \(room!)" : "")"
        case .activateScene(let name):
            return "Activate '\(name)' scene"
        case .unknown(let query):
            return "Unknown: \(query)"
        default:
            return "Other intent"
        }
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var color: Color {
        if confidence > 0.8 { return .green }
        if confidence > 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(Double(index) < confidence * 5 ? color : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

struct SuggestionsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try saying:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestions, id: \.self) { suggestion in
                        SuggestionChip(text: suggestion) {
                            onSelect(suggestion)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
}

struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(15)
        }
    }
}

struct NaturalLanguageInput: View {
    @Binding var text: String
    @Binding var isListening: Bool
    let isProcessing: Bool
    let onSubmit: () -> Void
    let onVoiceInput: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Voice input button
            Button(action: onVoiceInput) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .foregroundColor(isListening ? .red : .blue)
                    .scaleEffect(isListening ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), 
                              value: isListening)
            }
            
            // Text input
            TextField("Tell me what to do...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isProcessing || isListening)
                .onSubmit(onSubmit)
            
            // Send button
            Button(action: onSubmit) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(text.isEmpty ? .gray : .blue)
                }
            }
            .disabled(text.isEmpty || isProcessing || isListening)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Intent Feedback

struct IntentFeedbackView: View {
    let intent: NaturalLanguageControl.DeviceIntent
    let success: Bool
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(success ? .green : .red)
            
            VStack(alignment: .leading) {
                Text(success ? "Command executed" : "Command failed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
}