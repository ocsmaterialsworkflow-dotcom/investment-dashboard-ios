import Foundation

/// 토스증권 Open API 호출 클라이언트.
///
/// - 인증: OAuth2 `client_credentials` 로 발급한 액세스 토큰을 `Authorization: Bearer` 로 첨부.
///   클라이언트 자격증명(clientId/clientSecret)은 `SecretStore` 의
///   `.tossClientId` / `.tossClientSecret` 에서 읽는다. 없으면 `.missingCredentials`.
/// - 토큰 캐싱/갱신은 `OAuth2TokenProvider`(actor)가 담당한다.
///
/// ⚠️ 실제 응답 스키마·엔드포인트 경로는 발급 후 검증 필요.
public struct TossAPIClient: Sendable {

    public static let baseURL = URL(string: "https://openapi.tossinvest.com")!
    /// client_credentials 토큰 엔드포인트(추정). ⚠️ 실제 경로 검증 필요.
    public static let tokenURL = URL(string: "https://openapi.tossinvest.com/oauth2/token")!

    private let http: HTTPClient
    private let tokenProvider: OAuth2TokenProvider
    private let decoder: JSONDecoder

    /// `SecretStore` 에서 자격증명을 읽어 토큰 제공자를 구성한다.
    /// - Throws: 자격증명이 없으면 `NetworkError.missingCredentials`.
    public init(http: HTTPClient, secrets: SecretStore) throws {
        let clientId: String
        let clientSecret: String
        do {
            clientId = try secrets.load(for: .tossClientId)
            clientSecret = try secrets.load(for: .tossClientSecret)
        } catch {
            throw NetworkError.missingCredentials
        }

        self.http = http
        self.tokenProvider = OAuth2TokenProvider(
            http: http,
            tokenURL: Self.tokenURL,
            clientId: clientId,
            clientSecret: clientSecret
        )
        self.decoder = JSONDecoder()
    }

    /// 토큰 제공자를 직접 주입하는 생성자(테스트/커스터마이징용).
    public init(http: HTTPClient, tokenProvider: OAuth2TokenProvider) {
        self.http = http
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder()
    }

    /// 국내 주식 잔고 조회.
    public func fetchDomesticBalance() async throws -> TossDomesticBalanceResponse {
        let url = Self.baseURL.appendingPathComponent("api/v1/account/domestic/balance")
        return try await authorizedGet(TossDomesticBalanceResponse.self, url: url)
    }

    /// 해외(미국) 주식 잔고 조회.
    public func fetchOverseasBalance() async throws -> TossOverseasBalanceResponse {
        let url = Self.baseURL.appendingPathComponent("api/v1/account/overseas/balance")
        return try await authorizedGet(TossOverseasBalanceResponse.self, url: url)
    }

    private func authorizedGet<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        let token = try await tokenProvider.token()
        let request = HTTPRequest(
            method: .get,
            url: url,
            headers: ["Authorization": "Bearer \(token)"]
        )
        let data = try await http.send(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }
    }
}
