import SwiftUI
import DeepSeekKit

// Smart home device functions
struct SmartHomeDevices {
    
    // MARK: - Device Models
    
    enum DeviceType: String, CaseIterable, Codable {
        case light = "Light"
        case thermostat = "Thermostat"
        case lock = "Smart Lock"
        case camera = "Security Camera"
        case speaker = "Smart Speaker"
        case plug = "Smart Plug"
        case sensor = "Sensor"
        
        var icon: String {
            switch self {
            case .light: return "lightbulb.fill"
            case .thermostat: return "thermometer"
            case .lock: return "lock.fill"
            case .camera: return "camera.fill"
            case .speaker: return "hifispeaker.fill"
            case .plug: return "powerplug"
            case .sensor: return "sensor"
            }
        }
        
        var color: Color {
            switch self {
            case .light: return .yellow
            case .thermostat: return .orange
            case .lock: return .blue
            case .camera: return .purple
            case .speaker: return .green
            case .plug: return .gray
            case .sensor: return .cyan
            }
        }
    }
    
    struct Device: Identifiable, Codable {
        let id: String
        let name: String
        let type: DeviceType
        let room: String
        var isOnline: Bool
        var state: DeviceState
        var capabilities: Set<Capability>
        
        enum Capability: String, Codable {
            case power
            case dimming
            case colorControl
            case temperature
            case motion
            case recording
            case twoWayAudio
            case scheduling
        }
    }
    
    enum DeviceState: Codable {
        case light(on: Bool, brightness: Int, color: String?)
        case thermostat(temperature: Double, mode: ThermostatMode)
        case lock(locked: Bool, battery: Int)
        case camera(recording: Bool, motionDetected: Bool)
        case speaker(playing: Bool, volume: Int)
        case plug(on: Bool, powerUsage: Double?)
        case sensor(triggered: Bool, value: Double?)
        
        enum ThermostatMode: String, Codable {
            case off, heat, cool, auto
        }
    }
    
    // MARK: - Function Tools
    
    static func createDeviceFunctionTools() -> [ChatCompletionRequest.Tool] {
        [
            // Control device power
            FunctionBuilder()
                .withName("control_device")
                .withDescription("Turn a device on/off or adjust its settings")
                .addParameter(
                    "device_id",
                    type: .string,
                    description: "The device identifier",
                    required: true
                )
                .addParameter(
                    "action",
                    type: .string,
                    description: "Action to perform",
                    required: true,
                    enumValues: ["turn_on", "turn_off", "toggle", "set_brightness", "set_temperature", "lock", "unlock"]
                )
                .addParameter(
                    "value",
                    type: .number,
                    description: "Value for actions like brightness or temperature"
                )
                .build(),
            
            // Get device status
            FunctionBuilder()
                .withName("get_device_status")
                .withDescription("Get the current status of a device")
                .addParameter(
                    "device_id",
                    type: .string,
                    description: "The device identifier",
                    required: true
                )
                .build(),
            
            // List devices
            FunctionBuilder()
                .withName("list_devices")
                .withDescription("List all smart home devices")
                .addParameter(
                    "room",
                    type: .string,
                    description: "Filter by room"
                )
                .addParameter(
                    "type",
                    type: .string,
                    description: "Filter by device type",
                    enumValues: DeviceType.allCases.map { $0.rawValue }
                )
                .addParameter(
                    "online_only",
                    type: .boolean,
                    description: "Only show online devices",
                    defaultValue: false
                )
                .build(),
            
            // Create scene
            FunctionBuilder()
                .withName("execute_scene")
                .withDescription("Execute a predefined scene")
                .addParameter(
                    "scene_name",
                    type: .string,
                    description: "Name of the scene to execute",
                    required: true,
                    enumValues: ["morning", "night", "away", "movie", "party", "work"]
                )
                .build(),
            
            // Schedule action
            FunctionBuilder()
                .withName("schedule_action")
                .withDescription("Schedule a device action for later")
                .addParameter(
                    "device_id",
                    type: .string,
                    description: "The device identifier",
                    required: true
                )
                .addParameter(
                    "action",
                    type: .string,
                    description: "Action to schedule",
                    required: true
                )
                .addParameter(
                    "time",
                    type: .string,
                    description: "Time to execute (ISO 8601 format)",
                    required: true
                )
                .addParameter(
                    "repeat",
                    type: .string,
                    description: "Repeat pattern",
                    enumValues: ["once", "daily", "weekdays", "weekends"]
                )
                .build(),
            
            // Get energy usage
            FunctionBuilder()
                .withName("get_energy_usage")
                .withDescription("Get energy usage statistics")
                .addParameter(
                    "period",
                    type: .string,
                    description: "Time period for statistics",
                    required: true,
                    enumValues: ["today", "week", "month", "year"]
                )
                .addParameter(
                    "device_id",
                    type: .string,
                    description: "Specific device (optional)"
                )
                .build()
        ]
    }
}

// MARK: - Smart Home Manager

class SmartHomeManager: ObservableObject {
    @Published var devices: [SmartHomeDevices.Device] = []
    @Published var scenes: [Scene] = []
    @Published var automations: [Automation] = []
    @Published var isLoading = false
    
    struct Scene: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let actions: [DeviceAction]
        
        struct DeviceAction {
            let deviceId: String
            let action: String
            let value: Any?
        }
    }
    
    struct Automation: Identifiable {
        let id = UUID()
        let name: String
        let trigger: Trigger
        let conditions: [Condition]
        let actions: [Scene.DeviceAction]
        var isEnabled: Bool
        
        enum Trigger {
            case time(hour: Int, minute: Int)
            case deviceState(deviceId: String, state: String)
            case sensor(deviceId: String, threshold: Double)
            case location(entering: Bool)
        }
        
        struct Condition {
            let type: ConditionType
            
            enum ConditionType {
                case timeRange(start: Int, end: Int)
                case dayOfWeek(days: Set<Int>)
                case deviceState(deviceId: String, state: String)
            }
        }
    }
    
    init() {
        loadMockDevices()
        loadMockScenes()
    }
    
    private func loadMockDevices() {
        devices = [
            // Living Room
            SmartHomeDevices.Device(
                id: "light_001",
                name: "Living Room Light",
                type: .light,
                room: "Living Room",
                isOnline: true,
                state: .light(on: true, brightness: 80, color: nil),
                capabilities: [.power, .dimming]
            ),
            SmartHomeDevices.Device(
                id: "speaker_001",
                name: "Living Room Speaker",
                type: .speaker,
                room: "Living Room",
                isOnline: true,
                state: .speaker(playing: false, volume: 50),
                capabilities: [.power]
            ),
            
            // Bedroom
            SmartHomeDevices.Device(
                id: "light_002",
                name: "Bedroom Light",
                type: .light,
                room: "Bedroom",
                isOnline: true,
                state: .light(on: false, brightness: 0, color: "#FF0000"),
                capabilities: [.power, .dimming, .colorControl]
            ),
            SmartHomeDevices.Device(
                id: "thermostat_001",
                name: "Bedroom Thermostat",
                type: .thermostat,
                room: "Bedroom",
                isOnline: true,
                state: .thermostat(temperature: 72, mode: .auto),
                capabilities: [.temperature]
            ),
            
            // Kitchen
            SmartHomeDevices.Device(
                id: "plug_001",
                name: "Coffee Maker",
                type: .plug,
                room: "Kitchen",
                isOnline: true,
                state: .plug(on: false, powerUsage: 0),
                capabilities: [.power, .scheduling]
            ),
            
            // Entry
            SmartHomeDevices.Device(
                id: "lock_001",
                name: "Front Door",
                type: .lock,
                room: "Entry",
                isOnline: true,
                state: .lock(locked: true, battery: 85),
                capabilities: [.power]
            ),
            SmartHomeDevices.Device(
                id: "camera_001",
                name: "Front Door Camera",
                type: .camera,
                room: "Entry",
                isOnline: true,
                state: .camera(recording: true, motionDetected: false),
                capabilities: [.recording, .twoWayAudio]
            )
        ]
    }
    
    private func loadMockScenes() {
        scenes = [
            Scene(
                name: "Good Morning",
                icon: "sunrise.fill",
                actions: [
                    Scene.DeviceAction(deviceId: "light_001", action: "turn_on", value: 100),
                    Scene.DeviceAction(deviceId: "light_002", action: "turn_on", value: 50),
                    Scene.DeviceAction(deviceId: "plug_001", action: "turn_on", value: nil),
                    Scene.DeviceAction(deviceId: "thermostat_001", action: "set_temperature", value: 72)
                ]
            ),
            Scene(
                name: "Good Night",
                icon: "moon.fill",
                actions: [
                    Scene.DeviceAction(deviceId: "light_001", action: "turn_off", value: nil),
                    Scene.DeviceAction(deviceId: "light_002", action: "turn_off", value: nil),
                    Scene.DeviceAction(deviceId: "lock_001", action: "lock", value: nil),
                    Scene.DeviceAction(deviceId: "thermostat_001", action: "set_temperature", value: 68)
                ]
            ),
            Scene(
                name: "Movie Time",
                icon: "tv.fill",
                actions: [
                    Scene.DeviceAction(deviceId: "light_001", action: "set_brightness", value: 20),
                    Scene.DeviceAction(deviceId: "speaker_001", action: "turn_on", value: nil)
                ]
            )
        ]
    }
    
    // MARK: - Device Control
    
    func controlDevice(deviceId: String, action: String, value: Any? = nil) async -> Result<String, Error> {
        guard let device = devices.first(where: { $0.id == deviceId }) else {
            return .failure(SmartHomeError.deviceNotFound)
        }
        
        guard device.isOnline else {
            return .failure(SmartHomeError.deviceOffline)
        }
        
        // Simulate action execution
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Update device state
        await MainActor.run {
            if let index = devices.firstIndex(where: { $0.id == deviceId }) {
                switch action {
                case "turn_on":
                    updateDevicePower(at: index, on: true)
                case "turn_off":
                    updateDevicePower(at: index, on: false)
                case "toggle":
                    toggleDevicePower(at: index)
                case "set_brightness":
                    if let brightness = value as? Int {
                        updateDeviceBrightness(at: index, brightness: brightness)
                    }
                case "set_temperature":
                    if let temp = value as? Double {
                        updateDeviceTemperature(at: index, temperature: temp)
                    }
                case "lock":
                    updateDeviceLock(at: index, locked: true)
                case "unlock":
                    updateDeviceLock(at: index, locked: false)
                default:
                    break
                }
            }
        }
        
        return .success("Device \(device.name) \(action) completed")
    }
    
    private func updateDevicePower(at index: Int, on: Bool) {
        switch devices[index].state {
        case .light(_, let brightness, let color):
            devices[index].state = .light(on: on, brightness: brightness, color: color)
        case .speaker(_, let volume):
            devices[index].state = .speaker(playing: on, volume: volume)
        case .plug(_, let usage):
            devices[index].state = .plug(on: on, powerUsage: on ? 150.0 : 0.0)
        default:
            break
        }
    }
    
    private func toggleDevicePower(at index: Int) {
        switch devices[index].state {
        case .light(let on, let brightness, let color):
            devices[index].state = .light(on: !on, brightness: brightness, color: color)
        case .speaker(let playing, let volume):
            devices[index].state = .speaker(playing: !playing, volume: volume)
        case .plug(let on, _):
            devices[index].state = .plug(on: !on, powerUsage: !on ? 150.0 : 0.0)
        default:
            break
        }
    }
    
    private func updateDeviceBrightness(at index: Int, brightness: Int) {
        if case .light(let on, _, let color) = devices[index].state {
            devices[index].state = .light(on: on, brightness: brightness, color: color)
        }
    }
    
    private func updateDeviceTemperature(at index: Int, temperature: Double) {
        if case .thermostat(_, let mode) = devices[index].state {
            devices[index].state = .thermostat(temperature: temperature, mode: mode)
        }
    }
    
    private func updateDeviceLock(at index: Int, locked: Bool) {
        if case .lock(_, let battery) = devices[index].state {
            devices[index].state = .lock(locked: locked, battery: battery)
        }
    }
    
    func executeScene(_ sceneName: String) async -> Result<String, Error> {
        guard let scene = scenes.first(where: { $0.name.lowercased() == sceneName.lowercased() }) else {
            return .failure(SmartHomeError.sceneNotFound)
        }
        
        for action in scene.actions {
            _ = await controlDevice(deviceId: action.deviceId, action: action.action, value: action.value)
        }
        
        return .success("Scene '\(scene.name)' executed successfully")
    }
    
    enum SmartHomeError: LocalizedError {
        case deviceNotFound
        case deviceOffline
        case sceneNotFound
        case invalidAction
        
        var errorDescription: String? {
            switch self {
            case .deviceNotFound:
                return "Device not found"
            case .deviceOffline:
                return "Device is offline"
            case .sceneNotFound:
                return "Scene not found"
            case .invalidAction:
                return "Invalid action for this device"
            }
        }
    }
}

// MARK: - Smart Home UI

struct SmartHomeDevicesView: View {
    @StateObject private var manager = SmartHomeManager()
    @State private var selectedRoom: String?
    @State private var showingAutomations = false
    
    var rooms: [String] {
        Array(Set(manager.devices.map { $0.room })).sorted()
    }
    
    var filteredDevices: [SmartHomeDevices.Device] {
        if let room = selectedRoom {
            return manager.devices.filter { $0.room == room }
        }
        return manager.devices
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Room filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    RoomChip(
                        title: "All",
                        isSelected: selectedRoom == nil,
                        action: { selectedRoom = nil }
                    )
                    
                    ForEach(rooms, id: \.self) { room in
                        RoomChip(
                            title: room,
                            isSelected: selectedRoom == room,
                            action: { selectedRoom = room }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Scenes
            ScenesSection(scenes: manager.scenes) { scene in
                Task {
                    _ = await manager.executeScene(scene.name)
                }
            }
            
            // Devices
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(filteredDevices) { device in
                        DeviceCard(device: device) { action, value in
                            Task {
                                _ = await manager.controlDevice(
                                    deviceId: device.id,
                                    action: action,
                                    value: value
                                )
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Smart Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAutomations = true }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingAutomations) {
            AutomationsView(automations: manager.automations)
        }
    }
}

struct RoomChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ScenesSection: View {
    let scenes: [SmartHomeManager.Scene]
    let onExecute: (SmartHomeManager.Scene) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Scenes")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(scenes) { scene in
                        SceneCard(scene: scene) {
                            onExecute(scene)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SceneCard: View {
    let scene: SmartHomeManager.Scene
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPressed = false
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: scene.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                
                Text(scene.name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
    }
}

struct DeviceCard: View {
    let device: SmartHomeDevices.Device
    let onControl: (String, Any?) -> Void
    
    var isOn: Bool {
        switch device.state {
        case .light(let on, _, _): return on
        case .speaker(let playing, _): return playing
        case .plug(let on, _): return on
        case .lock(let locked, _): return !locked
        case .camera(let recording, _): return recording
        default: return false
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: device.type.icon)
                    .font(.title2)
                    .foregroundColor(device.type.color)
                
                Spacer()
                
                if !device.isOnline {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    Toggle("", isOn: .constant(isOn))
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onTapGesture {
                            onControl("toggle", nil)
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(device.room)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Device-specific controls
            DeviceControls(device: device, onControl: onControl)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(device.isOnline ? 1.0 : 0.6)
    }
}

struct DeviceControls: View {
    let device: SmartHomeDevices.Device
    let onControl: (String, Any?) -> Void
    
    var body: some View {
        switch device.state {
        case .light(_, let brightness, _):
            if device.capabilities.contains(.dimming) {
                BrightnessSlider(brightness: brightness) { newBrightness in
                    onControl("set_brightness", newBrightness)
                }
            }
            
        case .thermostat(let temperature, _):
            TemperatureControl(temperature: temperature) { newTemp in
                onControl("set_temperature", newTemp)
            }
            
        case .speaker(_, let volume):
            VolumeSlider(volume: volume) { newVolume in
                onControl("set_volume", newVolume)
            }
            
        case .lock(let locked, let battery):
            HStack {
                Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                    .foregroundColor(locked ? .green : .orange)
                
                Spacer()
                
                Label("\(battery)%", systemImage: "battery.100")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        default:
            EmptyView()
        }
    }
}

struct BrightnessSlider: View {
    let brightness: Int
    let onChange: (Int) -> Void
    
    @State private var sliderValue: Double
    
    init(brightness: Int, onChange: @escaping (Int) -> Void) {
        self.brightness = brightness
        self.onChange = onChange
        self._sliderValue = State(initialValue: Double(brightness))
    }
    
    var body: some View {
        HStack {
            Image(systemName: "sun.min")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(value: $sliderValue, in: 0...100, step: 5)
                .onChange(of: sliderValue) { newValue in
                    onChange(Int(newValue))
                }
            
            Text("\(Int(sliderValue))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 35)
        }
    }
}

struct TemperatureControl: View {
    let temperature: Double
    let onChange: (Double) -> Void
    
    var body: some View {
        HStack {
            Button(action: { onChange(temperature - 1) }) {
                Image(systemName: "minus.circle")
            }
            
            Spacer()
            
            Text("\(Int(temperature))°F")
                .font(.title3)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: { onChange(temperature + 1) }) {
                Image(systemName: "plus.circle")
            }
        }
    }
}

struct VolumeSlider: View {
    let volume: Int
    let onChange: (Int) -> Void
    
    @State private var sliderValue: Double
    
    init(volume: Int, onChange: @escaping (Int) -> Void) {
        self.volume = volume
        self.onChange = onChange
        self._sliderValue = State(initialValue: Double(volume))
    }
    
    var body: some View {
        HStack {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(value: $sliderValue, in: 0...100, step: 5)
                .onChange(of: sliderValue) { newValue in
                    onChange(Int(newValue))
                }
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct AutomationsView: View {
    let automations: [SmartHomeManager.Automation]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(automations) { automation in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(automation.name)
                                .font(.headline)
                            
                            Text(describeTrigger(automation.trigger))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(automation.isEnabled))
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("Automations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func describeTrigger(_ trigger: SmartHomeManager.Automation.Trigger) -> String {
        switch trigger {
        case .time(let hour, let minute):
            return String(format: "At %02d:%02d", hour, minute)
        case .deviceState(let deviceId, let state):
            return "When \(deviceId) is \(state)"
        case .sensor(let deviceId, let threshold):
            return "When \(deviceId) reaches \(threshold)"
        case .location(let entering):
            return entering ? "When arriving home" : "When leaving home"
        }
    }
}