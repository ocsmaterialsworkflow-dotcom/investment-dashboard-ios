import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

/// 한 번의 HTTP 요청을 표현하는 값 타입.
public struct HTTPRequest: Sendable, Equatable {
    public var method: HTTPMethod
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: HTTPMethod, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// 네트워크 전송 추상화. `UpbitAPIClient` 등은 이 프로토콜에 의존해
/// 테스트 시 고정 JSON 을 반환하는 목으로 대체할 수 있다.
public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> Data
}

/// URLSession 기반 기본 구현.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> Data {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.transport("Non-HTTP response")
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 429:
            throw NetworkError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.requestFailed(statusCode: http.statusCode, body: body)
        }
    }
}
