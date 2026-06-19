import Foundation

/// 한국투자증권(KIS) 액세스 토큰 제공자.
///
/// KIS 는 표준 OAuth2 form 바디가 아니라 **JSON 바디**로 토큰을 발급한다.
/// ```
/// POST /oauth2/tokenP
/// { "grant_type": "client_credentials", "appkey": "...", "appsecret": "..." }
/// ```
/// 응답의 `expires_in`(초)으로 만료를 계산하고, 만료 임박 시 자동 재발급한다.
/// 자격증명(appkey/appsecret)은 `SecretStore` 의 `.kisAppKey` / `.kisAppSecret` 에서 읽는다.
public actor KISAuthClient {

    private let http: HTTPClient
    private let baseURL: URL
    private let appKey: String
    private let appSecret: String
    private let refreshLeeway: TimeInterval
    private let decoder: JSONDecoder

    private var cachedToken: String?
    private var expiresAt: Date?

    /// `SecretStore` 에서 자격증명을 읽어 구성한다.
    /// - Throws: 자격증명이 없으면 `NetworkError.missingCredentials`.
    public init(
        http: HTTPClient,
        secrets: SecretStore,
        baseURL: URL = KISAPIClient.baseURL,
        refreshLeeway: TimeInterval = 60
    ) throws {
        let appKey: String
        let appSecret: String
        do {
            appKey = try secrets.load(for: .kisAppKey)
            appSecret = try secrets.load(for: .kisAppSecret)
        } catch {
            throw NetworkError.missingCredentials
        }
        self.http = http
        self.baseURL = baseURL
        self.appKey = appKey
        self.appSecret = appSecret
        self.refreshLeeway = refreshLeeway
        self.decoder = JSONDecoder()
    }

    /// 자격증명을 직접 주입하는 생성자(테스트용).
    public init(
        http: HTTPClient,
        appKey: String,
        appSecret: String,
        baseURL: URL = KISAPIClient.baseURL,
        refreshLeeway: TimeInterval = 60
    ) {
        self.http = http
        self.baseURL = baseURL
        self.appKey = appKey
        self.appSecret = appSecret
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

    @discardableResult
    private func refresh() async throws -> String {
        let body: [String: String] = [
            "grant_type": "client_credentials",
            "appkey": appKey,
            "appsecret": appSecret
        ]
        let bodyData = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()

        let request = HTTPRequest(
            method: .post,
            url: baseURL.appendingPathComponent("oauth2/tokenP"),
            headers: ["Content-Type": "application/json"],
            body: bodyData
        )

        let data = try await http.send(request)
        let decoded: KISTokenResponse
        do {
            decoded = try decoder.decode(KISTokenResponse.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }

        cachedToken = decoded.accessToken
        let ttl = decoded.expiresIn ?? 86_400
        expiresAt = Date().addingTimeInterval(ttl)
        return decoded.accessToken
    }
}
