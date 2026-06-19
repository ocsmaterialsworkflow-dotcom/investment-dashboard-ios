import Foundation

/// 한국은행 ECOS Open API 를 통해 USD/KRW 매매기준율을 조회하는 클라이언트.
///
/// 통계표 코드 `731Y001`, 항목 코드 `0000001`(원/미국달러 매매기준율) 기준.
/// 최근 7일 범위를 조회해 가장 최신 비-null 값을 반환한다.
public struct BOKExchangeRateClient: ExchangeRateProviding {

    /// ECOS API 기본 URL.
    public static let baseURL = "https://ecos.bok.or.kr/api/StatisticSearch"

    private let http: HTTPClient
    private let apiKey: String
    private let decoder: JSONDecoder

    public init(http: HTTPClient, apiKey: String) {
        self.http = http
        self.apiKey = apiKey
        self.decoder = JSONDecoder()
    }

    // MARK: - ExchangeRateProviding

    public func latestUSDKRW() async throws -> Double {
        let (startDate, endDate) = recentDateRange(days: 7)
        let urlString = "\(Self.baseURL)/\(apiKey)/json/kr/1/10/731Y001/D/\(startDate)/\(endDate)/0000001"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        let request = HTTPRequest(method: .get, url: url)
        let data = try await http.send(request)

        // ECOS 에러 엔벨로프 먼저 확인
        if let errorEnvelope = try? decoder.decode(BOKErrorEnvelope.self, from: data),
           errorEnvelope.result != nil {
            let code = errorEnvelope.result?.code ?? "UNKNOWN"
            let message = errorEnvelope.result?.message ?? "ECOS API 오류"
            throw NetworkError.requestFailed(statusCode: 0, body: "[\(code)] \(message)")
        }

        let envelope: BOKSearchEnvelope
        do {
            envelope = try decoder.decode(BOKSearchEnvelope.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }

        // 가장 최신 TIME 기준 내림차순 정렬 후 최초 유효 값 반환
        let rows = envelope.statisticSearch.row
            .sorted { $0.time > $1.time }

        for row in rows {
            let trimmed = row.dataValue.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, let value = Double(trimmed) {
                return value
            }
        }

        throw NetworkError.decodingFailed("유효한 환율 데이터 없음 (rows: \(rows.count))")
    }

    // MARK: - Private Helpers

    /// 오늘을 기준으로 `days`일 이전부터 오늘까지의 날짜 문자열 쌍 (yyyyMMdd).
    private func recentDateRange(days: Int) -> (start: String, end: String) {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return (formatter.string(from: start), formatter.string(from: today))
    }
}

// MARK: - Response Models (internal)

/// ECOS StatisticSearch 성공 응답 엔벨로프.
private struct BOKSearchEnvelope: Decodable {
    let statisticSearch: BOKStatisticSearch

    enum CodingKeys: String, CodingKey {
        case statisticSearch = "StatisticSearch"
    }
}

private struct BOKStatisticSearch: Decodable {
    let row: [BOKRow]
}

private struct BOKRow: Decodable {
    let dataValue: String
    let time: String

    enum CodingKeys: String, CodingKey {
        case dataValue = "DATA_VALUE"
        case time = "TIME"
    }
}

/// ECOS 에러 응답 엔벨로프. 오류 시 `RESULT` 키가 존재한다.
private struct BOKErrorEnvelope: Decodable {
    let result: BOKResultError?

    enum CodingKeys: String, CodingKey {
        case result = "RESULT"
    }
}

private struct BOKResultError: Decodable {
    let code: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code = "CODE"
        case message = "MESSAGE"
    }
}
