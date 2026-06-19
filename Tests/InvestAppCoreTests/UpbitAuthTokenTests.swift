import XCTest
import CryptoKit
@testable import InvestAppCore

final class UpbitAuthTokenTests: XCTestCase {

    private func decodeSegment(_ segment: String) -> [String: Any]? {
        var s = segment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // base64 패딩 복원
        while s.count % 4 != 0 { s += "=" }
        guard let data = Data(base64Encoded: s),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    func test_token_hasThreeSegments() {
        let token = UpbitAuthToken.make(accessKey: "ak", secretKey: "sk")
        XCTAssertEqual(token.split(separator: ".").count, 3)
    }

    func test_header_isHS256() {
        let token = UpbitAuthToken.make(accessKey: "ak", secretKey: "sk")
        let header = decodeSegment(String(token.split(separator: ".")[0]))
        XCTAssertEqual(header?["alg"] as? String, "HS256")
        XCTAssertEqual(header?["typ"] as? String, "JWT")
    }

    func test_payload_withoutQuery_hasAccessKeyAndNonce_butNoQueryHash() {
        let token = UpbitAuthToken.make(accessKey: "my-access", secretKey: "sk", nonce: "fixed-nonce")
        let payload = decodeSegment(String(token.split(separator: ".")[1]))
        XCTAssertEqual(payload?["access_key"] as? String, "my-access")
        XCTAssertEqual(payload?["nonce"] as? String, "fixed-nonce")
        XCTAssertNil(payload?["query_hash"])
        XCTAssertNil(payload?["query_hash_alg"])
    }

    func test_payload_withQuery_includesSha512QueryHash() {
        let query = ["market": "KRW-BTC", "count": "10"]
        let token = UpbitAuthToken.make(accessKey: "ak", secretKey: "sk", query: query)
        let payload = decodeSegment(String(token.split(separator: ".")[1]))

        XCTAssertEqual(payload?["query_hash_alg"] as? String, "SHA512")

        // 쿼리 문자열은 키 정렬: "count=10&market=KRW-BTC"
        let expectedString = "count=10&market=KRW-BTC"
        XCTAssertEqual(UpbitAuthToken.canonicalQueryString(query), expectedString)

        let expectedHash = UpbitAuthToken.sha512Hex(expectedString)
        XCTAssertEqual(payload?["query_hash"] as? String, expectedHash)
        XCTAssertEqual(expectedHash.count, 128) // SHA512 = 64 bytes = 128 hex chars
    }

    func test_signature_isValidHMACSHA256() {
        let token = UpbitAuthToken.make(accessKey: "ak", secretKey: "super-secret", nonce: "n")
        let parts = token.split(separator: ".").map(String.init)
        let signingInput = "\(parts[0]).\(parts[1])"

        let key = SymmetricKey(data: Data("super-secret".utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let expectedSig = Data(mac).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        XCTAssertEqual(parts[2], expectedSig)
    }

    func test_canonicalQueryString_sortsKeys() {
        let result = UpbitAuthToken.canonicalQueryString(["b": "2", "a": "1", "c": "3"])
        XCTAssertEqual(result, "a=1&b=2&c=3")
    }
}
