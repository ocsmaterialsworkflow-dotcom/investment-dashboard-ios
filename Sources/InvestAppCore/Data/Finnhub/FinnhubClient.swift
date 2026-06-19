import Foundation

/// Finnhub(`https://finnhub.io/api/v1`) 시세/배당 클라이언트.
///
/// 인증 토큰은 쿼리 파라미터 `token` 으로 전달한다 (`apiKey` 는 init 으로 주입).
public struct FinnhubClient: MarketDataProviding {

    public static let baseURL = URL(string: "https://finnhub.io/api/v1")!

    private let http: HTTPClient
    private let apiKey: String
    private let decoder: JSONDecoder

    /// 배당 날짜 파싱/포맷용 ("yyyy-MM-dd", UTC).
    private let dateFormatter: DateFormatter

    public init(http: HTTPClient, apiKey: String) {
        self.http = http
        self.apiKey = apiKey
        self.decoder = JSONDecoder()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = formatter
    }

    /// 현재가 (`GET /quote?symbol=&token=`).
    public func quote(symbol: String) async throws -> Double {
        let url = try makeURL(path: "quote", queryItems: [
            URLQueryItem(name: "symbol", value: symbol)
        ])
        let request = HTTPRequest(method: .get, url: url)
        let dto = try await decode(FinnhubQuote.self, from: request)
        return dto.c
    }

    /// 배당 일정 (`GET /stock/dividend?symbol=&from=&to=&token=`).
    ///
    /// `amount`(USD) → `amountPerShare` 로 매핑하며, `totalAmount` 는 0 으로 둔다
    /// (보유 수량/환율을 아는 상위 계층에서 채운다). `isConfirmed` 는 `true`.
    public func dividends(symbol: String, from: Date, to: Date) async throws -> [DividendSchedule] {
        let url = try makeURL(path: "stock/dividend", queryItems: [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "from", value: dateFormatter.string(from: from)),
            URLQueryItem(name: "to", value: dateFormatter.string(from: to))
        ])
        let request = HTTPRequest(method: .get, url: url)
        let dtos = try await decode([FinnhubDividend].self, from: request)

        return dtos.map { dto in
            let exDate = dateFormatter.date(from: dto.date) ?? Date(timeIntervalSince1970: 0)
            let payDate = dateFormatter.date(from: dto.payDate) ?? exDate
            return DividendSchedule(
                symbol: dto.symbol,
                exDividendDate: exDate,
                paymentDate: payDate,
                amountPerShare: dto.amount,
                totalAmount: 0,
                isConfirmed: true
            )
        }
    }

    // MARK: - Helpers

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems + [URLQueryItem(name: "token", value: apiKey)]
        guard let url = components?.url else { throw NetworkError.invalidURL }
        return url
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
