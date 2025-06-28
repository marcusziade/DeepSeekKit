import Foundation
#if os(Linux)
import FoundationNetworking
#endif

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
            return try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: DeepSeekError.networkError(error))
                        return
                    }
                    
                    guard let data = data,
                          let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(throwing: DeepSeekError.networkError(URLError(.badServerResponse)))
                        return
                    }
                    
                    switch httpResponse.statusCode {
                    case 200...299:
                        // Check for empty response which might indicate endpoint not available
                        if data.isEmpty {
                            continuation.resume(throwing: DeepSeekError.apiError(APIError(
                                type: "endpoint_not_available",
                                message: "This endpoint may not be available yet",
                                code: nil,
                                param: nil
                            )))
                            return
                        }
                        continuation.resume(returning: data)
                    case 401:
                        continuation.resume(throwing: DeepSeekError.invalidAPIKey)
                    case 402:
                        continuation.resume(throwing: DeepSeekError.insufficientBalance)
                    case 429:
                        continuation.resume(throwing: DeepSeekError.rateLimitExceeded)
                    case 503:
                        continuation.resume(throwing: DeepSeekError.serviceUnavailable)
                    default:
                        // Try to decode error response
                        if let errorResponse = try? self.decoder.decode(ErrorResponse.self, from: data) {
                            continuation.resume(throwing: DeepSeekError.apiError(errorResponse.error))
                        } else {
                            continuation.resume(throwing: DeepSeekError.networkError(URLError(.badServerResponse)))
                        }
                    }
                }
                task.resume()
            }
        } catch let error as DeepSeekError {
            throw error
        } catch {
            throw DeepSeekError.networkError(error)
        }
    }
}