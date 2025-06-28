import Foundation

/// Implementation of the model service.
final class ModelService: ModelServiceProtocol {
    private let networking: NetworkingProtocol
    private let requestBuilder: RequestBuilder
    
    init(networking: NetworkingProtocol, requestBuilder: RequestBuilder) {
        self.networking = networking
        self.requestBuilder = requestBuilder
    }
    
    func listModels() async throws -> [Model] {
        let request = requestBuilder.listModelsRequest()
        
        // Try to decode as ModelsResponse first
        do {
            let response = try await networking.perform(request, expecting: ModelsResponse.self)
            return response.data
        } catch {
            // If that fails, try to decode as array directly
            // Some APIs return the array directly without wrapper
            if let models = try? await networking.perform(request, expecting: [Model].self) {
                return models
            }
            
            // If both fail, throw the original error
            throw error
        }
    }
}