import Foundation

/// 업비트 Open API 호출 클라이언트.
///
/// - 인증 API(`/accounts`): Keychain 의 Access/Secret Key 로 JWT 생성 후 Bearer 헤더 첨부.
/// - 시세 API(`/ticker`): 인증 불필요.
public struct UpbitAPIClient: Sendable {

    public static let baseURL = URL(string: "https://api.upbit.com/v1")!

    private let http: HTTPClient
    private let secrets: SecretStore
    private let decoder: JSONDecoder

    public init(http: HTTPClient, secrets: SecretStore) {
        self.http = http
        self.secrets = secrets
        self.decoder = JSONDecoder()
    }

    /// 전체 잔고 조회 (`GET /accounts`, 인증 필요).
    public func fetchAccounts() async throws -> [UpbitAccount] {
        let accessKey: String
        let secretKey: String
        do {
            accessKey = try secrets.load(for: .upbitAccessKey)
            secretKey = try secrets.load(for: .upbitSecretKey)
        } catch {
            throw NetworkError.missingCredentials
        }

        let token = UpbitAuthToken.make(accessKey: accessKey, secretKey: secretKey)
        let request = HTTPRequest(
            method: .get,
            url: Self.baseURL.appendingPathComponent("accounts"),
            headers: ["Authorization": "Bearer \(token)"]
        )
        return try await decode([UpbitAccount].self, from: request)
    }

    /// 마켓 현재가 조회 (`GET /ticker?markets=...`, 인증 불필요).
    /// - Parameter markets: 마켓 코드 목록 (예: `["KRW-BTC", "KRW-ETH"]`)
    public func fetchTickers(markets: [String]) async throws -> [UpbitTicker] {
        guard !markets.isEmpty else { return [] }

        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("ticker"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "markets", value: markets.joined(separator: ","))]
        guard let url = components?.url else { throw NetworkError.invalidURL }

        let request = HTTPRequest(method: .get, url: url)
        return try await decode([UpbitTicker].self, from: request)
    }

    private func decode<T: Decodable>(_ type: T.Type, from request: HTTPRequest) async throws -> T {
        let data = try await http.send(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }
    }
}
