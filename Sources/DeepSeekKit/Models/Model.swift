import Foundation

/// Represents an available DeepSeek model.
public struct Model: Codable, Sendable, Identifiable {
    /// The model identifier.
    public let id: String
    
    /// Object type (always "model").
    public let object: String
    
    /// Unix timestamp of when the model was created.
    public let created: Int?
    
    /// The organization that owns the model.
    public let ownedBy: String
    
    private enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
    }
}

/// Response containing a list of models.
public struct ModelsResponse: Codable, Sendable {
    /// Object type (always "list").
    public let object: String
    
    /// Array of available models.
    public let data: [Model]
}