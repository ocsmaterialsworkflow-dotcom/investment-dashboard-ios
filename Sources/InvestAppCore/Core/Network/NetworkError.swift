import Foundation

public enum NetworkError: Error, Equatable {
    case invalidURL
    case missingCredentials          // Keychain 에 API 키가 없음
    case requestFailed(statusCode: Int, body: String)
    case decodingFailed(String)
    case rateLimited                 // 429
    case transport(String)           // URLSession 전송 오류
}
