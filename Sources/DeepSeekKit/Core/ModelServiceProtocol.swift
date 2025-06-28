import Foundation

/// Protocol defining the model service interface.
///
/// This protocol provides methods for retrieving information about
/// available DeepSeek models.
public protocol ModelServiceProtocol: Sendable {
    /// Lists all available models.
    ///
    /// - Returns: An array of available models.
    /// - Throws: `DeepSeekError` if the request fails.
    func listModels() async throws -> [Model]
}