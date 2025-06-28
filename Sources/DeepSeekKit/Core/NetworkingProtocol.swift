import Foundation
#if os(Linux)
import FoundationNetworking
#endif

/// Protocol defining the networking interface for API requests.
///
/// This protocol abstracts the underlying network implementation to
/// allow for testing and different transport mechanisms.
public protocol NetworkingProtocol: Sendable {
    /// Performs a network request and returns the decoded response.
    ///
    /// - Parameters:
    ///   - request: The URL request to perform.
    ///   - type: The type to decode the response into.
    /// - Returns: The decoded response object.
    /// - Throws: `DeepSeekError` if the request fails or decoding fails.
    func perform<T: Decodable>(_ request: URLRequest, expecting type: T.Type) async throws -> T
    
    /// Performs a network request and returns the raw data.
    ///
    /// - Parameter request: The URL request to perform.
    /// - Returns: The raw response data.
    /// - Throws: `DeepSeekError` if the request fails.
    func performRaw(_ request: URLRequest) async throws -> Data
}