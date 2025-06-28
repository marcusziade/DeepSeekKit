import SwiftUI
import DeepSeekKit

// Device registry system for dynamic device management
class DeviceRegistry: ObservableObject {
    @Published var registeredDevices: [String: RegisteredDevice] = [:]
    @Published var deviceCategories: [DeviceCategory] = []
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isScanning = false
    
    private let registryStorage = DeviceRegistryStorage()
    private var scanTimer: Timer?
    
    // MARK: - Models
    
    struct RegisteredDevice: Identifiable, Codable {
        let id: String
        let name: String
        let manufacturer: String
        let model: String
        let firmwareVersion: String
        let capabilities: DeviceCapabilities
        let connectionInfo: ConnectionInfo
        let registeredAt: Date
        var lastSeen: Date
        var customName: String?
        var room: String?
        var groups: Set<String>
        
        struct DeviceCapabilities: Codable {
            let functions: [FunctionDefinition]
            let properties: [PropertyDefinition]
            let events: [EventDefinition]
        }
        
        struct FunctionDefinition: Codable {
            let name: String
            let description: String
            let parameters: [ParameterDefinition]
            let returnType: String?
        }
        
        struct PropertyDefinition: Codable {
            let name: String
            let type: String
            let readable: Bool
            let writable: Bool
            let unit: String?
            let range: Range?
            
            struct Range: Codable {
                let min: Double
                let max: Double
                let step: Double?
            }
        }
        
        struct EventDefinition: Codable {
            let name: String
            let description: String
            let payload: [ParameterDefinition]
        }
        
        struct ParameterDefinition: Codable {
            let name: String
            let type: String
            let required: Bool
            let description: String?
            let defaultValue: String?
        }
        
        struct ConnectionInfo: Codable {
            let protocol: ConnectionProtocol
            let address: String
            let port: Int?
            let authMethod: AuthMethod
            
            enum ConnectionProtocol: String, Codable {
                case wifi, bluetooth, zigbee, zwave, thread
            }
            
            enum AuthMethod: String, Codable {
                case none, apiKey, oauth, certificate
            }
        }
    }
    
    struct DiscoveredDevice: Identifiable {
        let id = UUID()
        let identifier: String
        let name: String
        let type: String
        let signalStrength: Int
        let isSupported: Bool
    }
    
    struct DeviceCategory: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let color: Color
        let deviceTypes: [String]
    }
    
    // MARK: - Initialization
    
    init() {
        loadCategories()
        loadRegisteredDevices()
    }
    
    private func loadCategories() {
        deviceCategories = [
            DeviceCategory(
                name: "Lighting",
                icon: "lightbulb.fill",
                color: .yellow,
                deviceTypes: ["light", "dimmer", "rgb_light", "light_strip"]
            ),
            DeviceCategory(
                name: "Climate",
                icon: "thermometer",
                color: .orange,
                deviceTypes: ["thermostat", "heater", "ac", "fan"]
            ),
            DeviceCategory(
                name: "Security",
                icon: "lock.shield.fill",
                color: .blue,
                deviceTypes: ["lock", "camera", "motion_sensor", "door_sensor"]
            ),
            DeviceCategory(
                name: "Entertainment",
                icon: "tv.fill",
                color: .purple,
                deviceTypes: ["tv", "speaker", "media_player", "game_console"]
            ),
            DeviceCategory(
                name: "Appliances",
                icon: "washer.fill",
                color: .green,
                deviceTypes: ["washer", "dryer", "dishwasher", "refrigerator"]
            )
        ]
    }
    
    private func loadRegisteredDevices() {
        registeredDevices = registryStorage.loadDevices()
    }
    
    // MARK: - Device Discovery
    
    func startDeviceDiscovery() {
        isScanning = true
        discoveredDevices.removeAll()
        
        // Simulate device discovery
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.simulateDeviceDiscovery()
        }
        
        // Stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.stopDeviceDiscovery()
        }
    }
    
    func stopDeviceDiscovery() {
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    private func simulateDeviceDiscovery() {
        let mockDevices = [
            ("Philips Hue Bridge", "bridge", true),
            ("Smart Bulb A19", "light", true),
            ("Nest Thermostat", "thermostat", true),
            ("August Smart Lock", "lock", true),
            ("Unknown Device", "unknown", false)
        ]
        
        if let device = mockDevices.randomElement() {
            let discovered = DiscoveredDevice(
                identifier: UUID().uuidString.prefix(8).lowercased(),
                name: device.0,
                type: device.1,
                signalStrength: Int.random(in: 60...100),
                isSupported: device.2
            )
            
            if !discoveredDevices.contains(where: { $0.name == discovered.name }) {
                discoveredDevices.append(discovered)
            }
        }
    }
    
    // MARK: - Device Registration
    
    func registerDevice(_ discovered: DiscoveredDevice) async throws -> RegisteredDevice {
        // Simulate device registration process
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Create mock capabilities based on device type
        let capabilities = createCapabilities(for: discovered.type)
        
        let device = RegisteredDevice(
            id: discovered.identifier,
            name: discovered.name,
            manufacturer: "Mock Manufacturer",
            model: "Model X",
            firmwareVersion: "1.0.0",
            capabilities: capabilities,
            connectionInfo: RegisteredDevice.ConnectionInfo(
                protocol: .wifi,
                address: "192.168.1.\(Int.random(in: 100...200))",
                port: 8080,
                authMethod: .apiKey
            ),
            registeredAt: Date(),
            lastSeen: Date(),
            customName: nil,
            room: nil,
            groups: []
        )
        
        registeredDevices[device.id] = device
        registryStorage.saveDevices(registeredDevices)
        
        return device
    }
    
    func unregisterDevice(_ deviceId: String) {
        registeredDevices.removeValue(forKey: deviceId)
        registryStorage.saveDevices(registeredDevices)
    }
    
    func updateDevice(_ deviceId: String, customName: String? = nil, room: String? = nil) {
        guard var device = registeredDevices[deviceId] else { return }
        
        if let customName = customName {
            device.customName = customName
        }
        
        if let room = room {
            device.room = room
        }
        
        device.lastSeen = Date()
        registeredDevices[deviceId] = device
        registryStorage.saveDevices(registeredDevices)
    }
    
    // MARK: - Capabilities Generation
    
    private func createCapabilities(for deviceType: String) -> RegisteredDevice.DeviceCapabilities {
        switch deviceType {
        case "light":
            return lightCapabilities()
        case "thermostat":
            return thermostatCapabilities()
        case "lock":
            return lockCapabilities()
        default:
            return basicCapabilities()
        }
    }
    
    private func lightCapabilities() -> RegisteredDevice.DeviceCapabilities {
        RegisteredDevice.DeviceCapabilities(
            functions: [
                RegisteredDevice.FunctionDefinition(
                    name: "turn_on",
                    description: "Turn the light on",
                    parameters: [],
                    returnType: "boolean"
                ),
                RegisteredDevice.FunctionDefinition(
                    name: "turn_off",
                    description: "Turn the light off",
                    parameters: [],
                    returnType: "boolean"
                ),
                RegisteredDevice.FunctionDefinition(
                    name: "set_brightness",
                    description: "Set brightness level",
                    parameters: [
                        RegisteredDevice.ParameterDefinition(
                            name: "level",
                            type: "integer",
                            required: true,
                            description: "Brightness level (0-100)",
                            defaultValue: nil
                        )
                    ],
                    returnType: "boolean"
                )
            ],
            properties: [
                RegisteredDevice.PropertyDefinition(
                    name: "power",
                    type: "boolean",
                    readable: true,
                    writable: true,
                    unit: nil,
                    range: nil
                ),
                RegisteredDevice.PropertyDefinition(
                    name: "brightness",
                    type: "integer",
                    readable: true,
                    writable: true,
                    unit: "%",
                    range: RegisteredDevice.PropertyDefinition.Range(min: 0, max: 100, step: 1)
                )
            ],
            events: [
                RegisteredDevice.EventDefinition(
                    name: "state_changed",
                    description: "Light state has changed",
                    payload: [
                        RegisteredDevice.ParameterDefinition(
                            name: "power",
                            type: "boolean",
                            required: true,
                            description: nil,
                            defaultValue: nil
                        ),
                        RegisteredDevice.ParameterDefinition(
                            name: "brightness",
                            type: "integer",
                            required: false,
                            description: nil,
                            defaultValue: nil
                        )
                    ]
                )
            ]
        )
    }
    
    private func thermostatCapabilities() -> RegisteredDevice.DeviceCapabilities {
        RegisteredDevice.DeviceCapabilities(
            functions: [
                RegisteredDevice.FunctionDefinition(
                    name: "set_temperature",
                    description: "Set target temperature",
                    parameters: [
                        RegisteredDevice.ParameterDefinition(
                            name: "temperature",
                            type: "number",
                            required: true,
                            description: "Target temperature",
                            defaultValue: nil
                        )
                    ],
                    returnType: "boolean"
                ),
                RegisteredDevice.FunctionDefinition(
                    name: "set_mode",
                    description: "Set operating mode",
                    parameters: [
                        RegisteredDevice.ParameterDefinition(
                            name: "mode",
                            type: "string",
                            required: true,
                            description: "heat, cool, auto, off",
                            defaultValue: "auto"
                        )
                    ],
                    returnType: "boolean"
                )
            ],
            properties: [
                RegisteredDevice.PropertyDefinition(
                    name: "current_temperature",
                    type: "number",
                    readable: true,
                    writable: false,
                    unit: "°F",
                    range: nil
                ),
                RegisteredDevice.PropertyDefinition(
                    name: "target_temperature",
                    type: "number",
                    readable: true,
                    writable: true,
                    unit: "°F",
                    range: RegisteredDevice.PropertyDefinition.Range(min: 50, max: 90, step: 1)
                ),
                RegisteredDevice.PropertyDefinition(
                    name: "mode",
                    type: "string",
                    readable: true,
                    writable: true,
                    unit: nil,
                    range: nil
                )
            ],
            events: [
                RegisteredDevice.EventDefinition(
                    name: "temperature_changed",
                    description: "Temperature has changed",
                    payload: [
                        RegisteredDevice.ParameterDefinition(
                            name: "current",
                            type: "number",
                            required: true,
                            description: nil,
                            defaultValue: nil
                        ),
                        RegisteredDevice.ParameterDefinition(
                            name: "target",
                            type: "number",
                            required: true,
                            description: nil,
                            defaultValue: nil
                        )
                    ]
                )
            ]
        )
    }
    
    private func lockCapabilities() -> RegisteredDevice.DeviceCapabilities {
        RegisteredDevice.DeviceCapabilities(
            functions: [
                RegisteredDevice.FunctionDefinition(
                    name: "lock",
                    description: "Lock the door",
                    parameters: [],
                    returnType: "boolean"
                ),
                RegisteredDevice.FunctionDefinition(
                    name: "unlock",
                    description: "Unlock the door",
                    parameters: [
                        RegisteredDevice.ParameterDefinition(
                            name: "code",
                            type: "string",
                            required: false,
                            description: "Access code",
                            defaultValue: nil
                        )
                    ],
                    returnType: "boolean"
                )
            ],
            properties: [
                RegisteredDevice.PropertyDefinition(
                    name: "locked",
                    type: "boolean",
                    readable: true,
                    writable: true,
                    unit: nil,
                    range: nil
                ),
                RegisteredDevice.PropertyDefinition(
                    name: "battery",
                    type: "integer",
                    readable: true,
                    writable: false,
                    unit: "%",
                    range: RegisteredDevice.PropertyDefinition.Range(min: 0, max: 100, step: 1)
                )
            ],
            events: [
                RegisteredDevice.EventDefinition(
                    name: "lock_changed",
                    description: "Lock state has changed",
                    payload: [
                        RegisteredDevice.ParameterDefinition(
                            name: "locked",
                            type: "boolean",
                            required: true,
                            description: nil,
                            defaultValue: nil
                        ),
                        RegisteredDevice.ParameterDefinition(
                            name: "method",
                            type: "string",
                            required: true,
                            description: "manual, auto, remote",
                            defaultValue: nil
                        )
                    ]
                )
            ]
        )
    }
    
    private func basicCapabilities() -> RegisteredDevice.DeviceCapabilities {
        RegisteredDevice.DeviceCapabilities(
            functions: [
                RegisteredDevice.FunctionDefinition(
                    name: "get_status",
                    description: "Get device status",
                    parameters: [],
                    returnType: "object"
                )
            ],
            properties: [
                RegisteredDevice.PropertyDefinition(
                    name: "online",
                    type: "boolean",
                    readable: true,
                    writable: false,
                    unit: nil,
                    range: nil
                )
            ],
            events: []
        )
    }
    
    // MARK: - Dynamic Function Generation
    
    func generateFunctionTools(for deviceId: String) -> [ChatCompletionRequest.Tool] {
        guard let device = registeredDevices[deviceId] else { return [] }
        
        return device.capabilities.functions.map { function in
            let builder = FunctionBuilder()
                .withName("\(deviceId)_\(function.name)")
                .withDescription("\(device.name): \(function.description)")
            
            for param in function.parameters {
                let paramType: FunctionBuilder.ParameterType = {
                    switch param.type {
                    case "string": return .string
                    case "number": return .number
                    case "integer": return .integer
                    case "boolean": return .boolean
                    default: return .string
                    }
                }()
                
                builder.addParameter(
                    param.name,
                    type: paramType,
                    description: param.description,
                    required: param.required,
                    defaultValue: param.defaultValue
                )
            }
            
            return builder.build()
        }
    }
}

// MARK: - Storage

class DeviceRegistryStorage {
    private let storageKey = "device_registry"
    
    func saveDevices(_ devices: [String: DeviceRegistry.RegisteredDevice]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    func loadDevices() -> [String: DeviceRegistry.RegisteredDevice] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let devices = try? JSONDecoder().decode(
                [String: DeviceRegistry.RegisteredDevice].self,
                from: data
              ) else {
            return [:]
        }
        return devices
    }
}

// MARK: - UI Components

struct DeviceRegistryView: View {
    @StateObject private var registry = DeviceRegistry()
    @State private var showingDiscovery = false
    @State private var selectedCategory: DeviceRegistry.DeviceCategory?
    
    var body: some View {
        VStack {
            // Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(registry.deviceCategories) { category in
                        CategoryCard(category: category) {
                            selectedCategory = category
                        }
                    }
                }
                .padding()
            }
            
            // Registered devices
            if registry.registeredDevices.isEmpty {
                EmptyRegistryView {
                    showingDiscovery = true
                }
            } else {
                RegisteredDevicesList(
                    devices: Array(registry.registeredDevices.values),
                    selectedCategory: selectedCategory
                )
            }
        }
        .navigationTitle("Device Registry")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingDiscovery = true }) {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showingDiscovery) {
            DeviceDiscoveryView(registry: registry)
        }
    }
}

struct CategoryCard: View {
    let category: DeviceRegistry.DeviceCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(category.color)
                    .cornerRadius(12)
                
                Text(category.name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct EmptyRegistryView: View {
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cpu")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Devices Registered")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add devices to start building your smart home")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAdd) {
                Label("Discover Devices", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct RegisteredDevicesList: View {
    let devices: [DeviceRegistry.RegisteredDevice]
    let selectedCategory: DeviceRegistry.DeviceCategory?
    
    var filteredDevices: [DeviceRegistry.RegisteredDevice] {
        if let category = selectedCategory {
            // Filter by category device types
            return devices // Implement filtering logic
        }
        return devices
    }
    
    var body: some View {
        List {
            ForEach(filteredDevices) { device in
                RegisteredDeviceRow(device: device)
            }
        }
    }
}

struct RegisteredDeviceRow: View {
    let device: DeviceRegistry.RegisteredDevice
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.customName ?? device.name)
                        .font(.headline)
                    
                    HStack {
                        Label(device.room ?? "No Room", systemImage: "house")
                        
                        Label(device.connectionInfo.protocol.rawValue.capitalized, 
                              systemImage: "wifi")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            
            if isExpanded {
                DeviceCapabilitiesView(device: device)
                    .padding(.top)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DeviceCapabilitiesView: View {
    let device: DeviceRegistry.RegisteredDevice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Functions
            if !device.capabilities.functions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Functions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(device.capabilities.functions, id: \.name) { function in
                        HStack {
                            Image(systemName: "function")
                                .font(.caption)
                            Text(function.name)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            // Properties
            if !device.capabilities.properties.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Properties")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(device.capabilities.properties, id: \.name) { property in
                        HStack {
                            Image(systemName: property.writable ? "pencil.circle" : "eye")
                                .font(.caption)
                            Text(property.name)
                                .font(.caption)
                            if let unit = property.unit {
                                Text("(\(unit))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
            }
        }
    }
}

struct DeviceDiscoveryView: View {
    @ObservedObject var registry: DeviceRegistry
    @Environment(\.dismiss) var dismiss
    @State private var selectedDevice: DeviceRegistry.DiscoveredDevice?
    @State private var isRegistering = false
    
    var body: some View {
        NavigationView {
            VStack {
                if registry.isScanning {
                    ScanningView()
                }
                
                List {
                    ForEach(registry.discoveredDevices) { device in
                        DiscoveredDeviceRow(device: device) {
                            selectedDevice = device
                        }
                        .disabled(!device.isSupported)
                    }
                }
                
                if !registry.isScanning && registry.discoveredDevices.isEmpty {
                    ContentUnavailableView(
                        "No Devices Found",
                        systemImage: "wifi.slash",
                        description: Text("Make sure your devices are powered on and in pairing mode")
                    )
                }
            }
            .navigationTitle("Discover Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        registry.stopDeviceDiscovery()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if registry.isScanning {
                        Button("Stop") {
                            registry.stopDeviceDiscovery()
                        }
                    } else {
                        Button("Scan") {
                            registry.startDeviceDiscovery()
                        }
                    }
                }
            }
            .onAppear {
                registry.startDeviceDiscovery()
            }
            .sheet(item: $selectedDevice) { device in
                DeviceRegistrationView(
                    device: device,
                    registry: registry,
                    isRegistering: $isRegistering
                )
            }
        }
    }
}

struct ScanningView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(rotation))
                .animation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false),
                    value: rotation
                )
                .onAppear {
                    rotation = 360
                }
            
            Text("Scanning for devices...")
                .font(.headline)
            
            ProgressView()
        }
        .padding()
    }
}

struct DiscoveredDeviceRow: View {
    let device: DeviceRegistry.DiscoveredDevice
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(device.type.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        SignalStrengthIndicator(strength: device.signalStrength)
                    }
                }
                
                Spacer()
                
                if device.isSupported {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                } else {
                    Text("Not Supported")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .disabled(!device.isSupported)
    }
}

struct SignalStrengthIndicator: View {
    let strength: Int
    
    var bars: Int {
        switch strength {
        case 0..<20: return 1
        case 20..<40: return 2
        case 40..<60: return 3
        case 60..<80: return 4
        default: return 5
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { bar in
                Rectangle()
                    .fill(bar <= bars ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat(bar * 3))
            }
        }
    }
}

struct DeviceRegistrationView: View {
    let device: DeviceRegistry.DiscoveredDevice
    let registry: DeviceRegistry
    @Binding var isRegistering: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var customName = ""
    @State private var selectedRoom = "Living Room"
    @State private var registrationError: Error?
    
    let rooms = ["Living Room", "Bedroom", "Kitchen", "Bathroom", "Office", "Garage"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Device Information") {
                    LabeledContent("Name", value: device.name)
                    LabeledContent("Type", value: device.type.capitalized)
                    LabeledContent("ID", value: device.identifier)
                }
                
                Section("Customization") {
                    TextField("Custom Name (Optional)", text: $customName)
                    
                    Picker("Room", selection: $selectedRoom) {
                        ForEach(rooms, id: \.self) { room in
                            Text(room).tag(room)
                        }
                    }
                }
            }
            .navigationTitle("Register Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Register") {
                        Task {
                            await registerDevice()
                        }
                    }
                    .disabled(isRegistering)
                }
            }
            .alert("Registration Failed", 
                   isPresented: .constant(registrationError != nil),
                   presenting: registrationError) { _ in
                Button("OK") { registrationError = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func registerDevice() async {
        isRegistering = true
        
        do {
            let registered = try await registry.registerDevice(device)
            registry.updateDevice(
                registered.id,
                customName: customName.isEmpty ? nil : customName,
                room: selectedRoom
            )
            dismiss()
        } catch {
            registrationError = error
        }
        
        isRegistering = false
    }
}