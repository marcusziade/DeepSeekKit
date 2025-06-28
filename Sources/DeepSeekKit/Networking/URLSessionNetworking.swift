import Foundation

/// URLSession-based implementation of the networking protocol.
final class URLSessionNetworking: NetworkingProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }
    
    func perform<T: Decodable>(_ request: URLRequest, expecting type: T.Type) async throws -> T {
        let data = try await performRaw(request)
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            // Try to decode as error response
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw DeepSeekError.apiError(errorResponse.error)
            }
            
            // For debugging: print raw response when decoding fails
            #if DEBUG
            if let rawString = String(data: data, encoding: .utf8) {
                print("DEBUG: Raw response that failed to decode:")
                print(rawString)
            }
            #endif
            
            throw DeepSeekError.decodingError(error)
        }
    }
    
    func performRaw(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DeepSeekError.networkError(URLError(.badServerResponse))
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                // Check for empty response which might indicate endpoint not available
                if data.isEmpty {
                    throw DeepSeekError.apiError(APIError(
                        type: "endpoint_not_available",
                        message: "This endpoint may not be available yet",
                        code: nil,
                        param: nil
                    ))
                }
                return data
            case 401:
                throw DeepSeekError.invalidAPIKey
            case 402:
                throw DeepSeekError.insufficientBalance
            case 429:
                throw DeepSeekError.rateLimitExceeded
            case 503:
                throw DeepSeekError.serviceUnavailable
            default:
                // Try to decode error response
                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                    throw DeepSeekError.apiError(errorResponse.error)
                }
                throw DeepSeekError.networkError(URLError(.badServerResponse))
            }
        } catch let error as DeepSeekError {
            throw error
        } catch {
            throw DeepSeekError.networkError(error)
        }
    }
}