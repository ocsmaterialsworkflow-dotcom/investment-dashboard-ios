import Foundation
import CryptoKit

/// 업비트 Open API 인증용 JWT 토큰 생성기.
///
/// 업비트는 매 요청마다 Access Key + Secret Key 로 서명한 JWT 를
/// `Authorization: Bearer <token>` 헤더로 전달한다.
///
/// - 서명: HMAC-SHA256 (HS256)
/// - 쿼리 파라미터가 있으면 `query_hash`(쿼리 문자열의 SHA512 hex) 와
///   `query_hash_alg = "SHA512"` 클레임을 포함한다.
/// - 토큰은 **메모리에서만** 사용하고 저장하지 않는다.
///   (Secret Key 자체는 `KeychainManager` 가 보관)
public enum UpbitAuthToken {

    /// 업비트 JWT 를 생성한다.
    /// - Parameters:
    ///   - accessKey: 업비트 발급 Access Key
    ///   - secretKey: 업비트 발급 Secret Key (HMAC 서명 키)
    ///   - query: 요청 쿼리 파라미터. 없으면 인증 전용 토큰.
    ///   - nonce: 멱등 방지용 난수. 기본값 UUID v4.
    /// - Returns: `header.payload.signature` 형식의 JWT 문자열.
    public static func make(
        accessKey: String,
        secretKey: String,
        query: [String: String] = [:],
        nonce: String = UUID().uuidString
    ) -> String {
        var payload: [String: Any] = [
            "access_key": accessKey,
            "nonce": nonce
        ]

        if !query.isEmpty {
            let queryString = canonicalQueryString(query)
            payload["query_hash"] = sha512Hex(queryString)
            payload["query_hash_alg"] = "SHA512"
        }

        let header: [String: Any] = ["alg": "HS256", "typ": "JWT"]
        let headerSegment = base64URLEncode(jsonData(header))
        let payloadSegment = base64URLEncode(jsonData(payload))
        let signingInput = "\(headerSegment).\(payloadSegment)"

        let key = SymmetricKey(data: Data(secretKey.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let signatureSegment = base64URLEncode(Data(mac))

        return "\(signingInput).\(signatureSegment)"
    }

    /// 업비트 규칙에 맞는 쿼리 문자열을 만든다.
    /// 키를 정렬해 `key=value&key=value` 형태로 결합한다.
    /// (요청에 사용한 쿼리 문자열과 `query_hash` 가 일치해야 하므로 동일 규칙을 적용)
    static func canonicalQueryString(_ query: [String: String]) -> String {
        query.keys.sorted()
            .map { "\($0)=\(query[$0] ?? "")" }
            .joined(separator: "&")
    }

    static func sha512Hex(_ string: String) -> String {
        SHA512.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func jsonData(_ object: [String: Any]) -> Data {
        // sortedKeys: 출력 결정성 확보(테스트 가능). JWT 유효성에는 키 순서 무관.
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
