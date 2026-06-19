# 투자 모아보기 iOS — 아키텍처 & 진행 현황

## 검증 결과 요약 (2026-06)

프로젝트 시작 전 필수 검증 6항목 결과:

| 항목 | 결과 | 비고 |
|------|------|------|
| 업비트 Open API | ✅ 사용 가능 | JWT(HS256) + 쿼리 SHA512 해시. 개인 키 보유 |
| NH투자증권 Open API | ❌ iOS 직접연동 불가 | QV Open API 는 **Windows DLL/C++ 전용**, REST/모바일 미지원 |
| 토스증권 Open API | ⚠️ 권한 확인 필요 | 2025~2026 공개, **OAuth2 Client Credentials** (WebView Auth Code 아님) |
| 미국주식 시세 | ⚠️ 미정 | 추천: 증권사 API 시세 또는 Finnhub 등 외부 |
| 배당 데이터 | ⚠️ 미정 | 추천 진행 중 |
| App Store 심사 | ⚠️ 조건부 | 개인용 우선 → 정식 배포 시 데이터 출처/키 입력 소명 필요 |

### 마이데이터 중계 경로 결론
- **공식 마이데이터(본인신용정보관리업)**: 금융위 인가 필요 → 개인 사용 **불가**.
- **상용 스크래핑 집계 API(CODEF/쿠콘)**: 기술적으로 NH 잔고 조회 가능하나
  자체 백엔드 서버 + (보통)사업자 계약 + 사용자 자격증명 보관이 필요 →
  1인 개인용 앱에는 과한 비용·보안 리스크. **별도 트랙으로 보류.**

## 모듈 구조

```
InvestAppCore (SwiftPM 라이브러리, 본 패키지)
├── Security/      KeychainManager, InMemorySecretStore, UpbitAuthToken(JWT)
├── Domain/Models/ Holding, Account (+ 환율 변환 로직)
└── Data/Upbit/    UpbitModels(API 응답), UpbitMapper(응답→도메인 변환)

InvestApp (Xcode SwiftUI 앱 타깃 — 추후 추가)
└── 위 InvestAppCore 를 의존성으로 가져와 화면/네트워크 연결
```

**설계 결정**: 플랫폼 의존이 낮은 순수 로직을 `InvestAppCore` 로 분리해
TDD/CI 단독 실행이 가능하게 했다. SwiftUI/네트워크/SwiftData 는 앱 타깃에서 결합한다.

## 보안 원칙
- API 키는 **Keychain 전용**(`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- 업비트 JWT 는 매 요청 생성, **메모리에서만** 사용·저장 금지.
- 모든 USD 금액은 **표시 직전에만** KRW 변환(중간 계산은 원 통화 유지).

## 테스트 실행
> ⚠️ 이 코드는 CryptoKit/Security 를 사용하므로 **macOS/Xcode 에서만** 빌드·테스트된다.
> (현재 CI 리눅스 환경에는 Swift 툴체인 없음 — 미컴파일 상태로 커밋됨)

```bash
swift test            # macOS
# 또는 Xcode 에서 ⌘U
```

## 로드맵
- [x] Phase 1: 기반(Keychain, JWT, 도메인 모델, Upbit 매퍼) + 단위 테스트
- [ ] Phase 2: UpbitAPIClient(네트워크) → 잔고/시세 → HomeView
- [ ] Phase 3: 환율(한국은행 ECOS API) + USD 변환
- [ ] Phase 4: 토스증권 OAuth2 / KIS(선택)
- [ ] Phase 5: 분석·배당·추이·비중 (Swift Charts)
- [ ] Phase 6: 위젯·알림·개인 배포
- [ ] 보류: NH (백엔드 + CODEF 별도 트랙)
