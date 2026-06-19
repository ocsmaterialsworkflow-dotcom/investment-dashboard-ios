import Foundation

/// open.er-api.com 을 사용하는 무료 fallback 환율 클라이언트.
///
/// 엔드포인트: `GET https://open.er-api.com/v6/latest/USD`
/// 응답: `{ "result": "success", "rates": { "KRW": 1380.5 } }`
public struct FallbackExchangeRateClient: ExchangeRateProviding {

    /// open.er-api 기본 URL.
    public static let endpointURL = URL(string: "https://open.er-api.com/v6/latest/USD")!

    private let http: HTTPClient
    private let decoder: JSONDecoder

    public init(http: HTTPClient) {
        self.http = http
        self.decoder = JSONDecoder()
    }

    // MARK: - ExchangeRateProviding

    public func latestUSDKRW() async throws -> Double {
        let request = HTTPRequest(method: .get, url: Self.endpointURL)
        let data = try await http.send(request)

        let response: ERAPIResponse
        do {
            response = try decoder.decode(ERAPIResponse.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }

        guard response.result == "success" else {
            throw NetworkError.requestFailed(statusCode: 0, body: "open.er-api: result=\(response.result)")
        }

        guard let krw = response.rates["KRW"] else {
            throw NetworkError.decodingFailed("KRW 환율 키가 응답에 없음")
        }

        return krw
    }
}

// MARK: - Response Model (internal)

private struct ERAPIResponse: Decodable {
    let result: String
    let rates: [String: Double]
}
