import Foundation

/// OAuth2 `client_credentials` 그랜트용 범용 액세스 토큰 제공자.
///
/// 발급받은 `access_token` 과 만료 시각을 액터 내부에 캐싱하고,
/// 만료가 임박하면(기본 60초 여유) 자동으로 재발급한다.
/// 토스증권 등 표준 client_credentials 토큰 엔드포인트에 사용한다.
///
/// 기대 응답 형식:
/// ```json
/// { "access_token": "...", "token_type": "Bearer", "expires_in": 86400 }
/// ```
/// - Note: 토큰 자체는 메모리에만 캐싱한다. 영속 저장이 필요하면 호출 측에서 `SecretStore` 에 보관한다.
public actor OAuth2TokenProvider {

    /// 토큰 엔드포인트 응답 DTO.
    private struct TokenResponse: Decodable {
        let accessToken: String
        let tokenType: String?
        let expiresIn: Double?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
        }
    }

    private let http: HTTPClient
    private let tokenURL: URL
    private let clientId: String
    private let clientSecret: String
    private let extraParams: [String: String]
    /// 만료 전 미리 갱신할 여유 시간(초).
    private let refreshLeeway: TimeInterval
    private let decoder: JSONDecoder

    private var cachedToken: String?
    private var expiresAt: Date?

    public init(
        http: HTTPClient,
        tokenURL: URL,
        clientId: String,
        clientSecret: String,
        extraParams: [String: String] = [:],
        refreshLeeway: TimeInterval = 60
    ) {
        self.http = http
        self.tokenURL = tokenURL
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.extraParams = extraParams
        self.refreshLeeway = refreshLeeway
        self.decoder = JSONDecoder()
    }

    /// 유효한 액세스 토큰을 반환한다. 캐시가 유효하면 재사용, 아니면 재발급한다.
    public func token() async throws -> String {
        if let cachedToken, let expiresAt, Date() < expiresAt.addingTimeInterval(-refreshLeeway) {
            return cachedToken
        }
        return try await refresh()
    }

    /// 강제로 새 토큰을 발급받아 캐시를 갱신한다.
    @discardableResult
    private func refresh() async throws -> String {
        let request = HTTPRequest(
            method: .post,
            url: tokenURL,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: Data(formBody().utf8)
        )

        let data = try await http.send(request)
        let decoded: TokenResponse
        do {
            decoded = try decoder.decode(TokenResponse.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }

        cachedToken = decoded.accessToken
        // expires_in 미제공 시 보수적으로 5분 사용.
        let ttl = decoded.expiresIn ?? 300
        expiresAt = Date().addingTimeInterval(ttl)
        return decoded.accessToken
    }

    /// `application/x-www-form-urlencoded` 바디 문자열을 만든다.
    private func formBody() -> String {
        var params = [
            "grant_type": "client_credentials",
            "client_id": clientId,
            "client_secret": clientSecret
        ]
        for (key, value) in extraParams { params[key] = value }

        return params
            .map { "\(Self.encode($0.key))=\(Self.encode($0.value))" }
            .joined(separator: "&")
    }

    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
