# 투자 모아보기 (Investment Dashboard) — iOS

개인용 iOS 투자 자산 통합 관리 앱. **업비트(코인) + 국내외 증권사**의 자산을 한 화면에서 모아봅니다.

- **플랫폼**: iOS 17+ / Swift 5.9+ / SwiftUI
- **아키텍처**: MVVM + Clean Architecture, 순수 로직을 `InvestAppCore` SwiftPM 패키지로 분리
- **성격**: 개인 앱(마이데이터 인가 없음) — 각 사 Open API를 직접 연동

[![CI](https://github.com/ocsmaterialsworkflow-dotcom/investment-dashboard-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/ocsmaterialsworkflow-dotcom/investment-dashboard-ios/actions/workflows/ci.yml)

---

## 🔍 연동 가능성 검증 결과 (반드시 확인)

| 데이터 소스 | 상태 | 비고 |
|------------|------|------|
| **업비트** Open API | ✅ 사용 가능 | JWT(HS256) + 쿼리 SHA512. 개인 키 발급 |
| **토스증권** Open API | ✅ 구현(검증대기) | OAuth2 **Client Credentials**. 발급 권한 필요 |
| **한국투자증권(KIS)** | ✅ 구현(검증대기) | REST OpenAPI, 크로스플랫폼. NH 대체 |
| **NH투자증권** | ❌ **iOS 직접연동 불가** | QV API가 **Windows DLL 전용**. 브릿지 백엔드 필요(placeholder) |
| 미국주식 시세·배당 | ✅ Finnhub | 무료티어, 시세 + 배당 일정 |
| 환율(USD/KRW) | ✅ 한국은행 ECOS | 실패 시 open.er-api.com fallback |

> **NH투자증권 주의**: 나무증권 QV Open API는 Windows DLL/C++ 전용이라 iOS에서 직접 호출할 수 없습니다.
> `developers.nonghyup.com`은 농협**은행** REST 플랫폼으로 증권 잔고와 무관합니다.
> NH 통합 조회는 별도의 **백엔드 브릿지**(자체 Windows 서버 또는 CODEF 같은 집계 API + 사업자 계약)가 전제이며,
> `NHBridgeAccountProvider` 가 자리표시자로 마련되어 있습니다.

---

## 🏗️ 프로젝트 구조

```
InvestAppCore (SwiftPM 라이브러리 — 테스트/CI 대상)
├── Core/
│   ├── Network/      HTTPClient, NetworkError, OAuth2TokenProvider
│   ├── Security/     KeychainManager, UpbitAuthToken(JWT), SecretStore
│   └── Utils/        ExchangeRateManager, CurrencyFormat
├── Domain/
│   ├── Models/       Holding, Account, DividendSchedule, AssetSnapshot
│   ├── UseCases/     ProfitAnalysis, Dividend, Trend, PortfolioWeight, FetchTotalAssets
│   ├── AnalysisPeriod, MarketDataProviding, BrokerAccountProviding
│   └── Presentation/ *ViewModel (SwiftUI 비의존, 단위 테스트 가능)
└── Data/
    ├── Upbit/        UpbitAPIClient, UpbitRepository, UpbitMapper
    ├── TossSecurities/ TossAPIClient, TossRepository
    ├── KIS/          KISAPIClient, KISRepository, KISAuthClient
    ├── NHInvestment/ NHBridgeAccountProvider (placeholder)
    ├── Finnhub/      FinnhubClient (시세·배당)
    └── ExchangeRate/ BOK(ECOS) + Fallback + Repository

App/ (Xcode SwiftUI 앱 타깃 — 패키지 외부, Xcode 에서 빌드)
├── InvestApp/        InvestAppApp, AppDependencyContainer, Theme
│   ├── Features/     Home, Analysis, Dividend, Trend, Portfolio, Settings (View)
│   └── Services/     NotificationScheduler (배당 알림)
└── InvestWidget/     WidgetKit 총자산 위젯
```

**설계 의도**: 플랫폼 의존이 낮은 모든 로직(네트워크/보안/도메인/ViewModel)을 `InvestAppCore` 에 모아
`swift test` 와 CI 에서 단독 검증합니다. SwiftUI 화면/위젯/알림만 앱 타깃에 둡니다.

---

## 🔐 보안 원칙

- **API 키는 Keychain 전용** (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). UserDefaults/plist/소스 저장 금지.
- 업비트 JWT 는 **요청마다 생성**, 메모리에서만 사용(저장 안 함).
- 모든 USD 금액은 **화면 표시 직전에만** KRW 로 변환(중간 계산은 원 통화 유지).
- `.gitignore` 에 시크릿 파일 패턴 차단.

---

## ▶️ 빌드 & 테스트

> 코어 패키지는 CryptoKit/Security 를 사용하므로 **macOS / Xcode** 에서 빌드됩니다.

```bash
swift build          # InvestAppCore 빌드
swift test           # 단위 테스트 (CI 와 동일)
```

전체 앱 실행은 Xcode 에서 `App/` 의 SwiftUI 타깃을 포함한 프로젝트를 구성한 뒤 실행합니다.

### 필요한 API 키 (앱 내 설정 화면에서 입력 → Keychain 저장)
| 키 | 발급처 |
|----|--------|
| 업비트 Access/Secret | upbit.com 마이페이지 |
| 토스 Client ID/Secret | developers.tossinvest.com |
| KIS App Key/Secret | apiportal.koreainvestment.com |
| 한국은행 ECOS Key | ecos.bok.or.kr |
| Finnhub Key | finnhub.io |

---

## 🗺️ 진행 현황

- [x] Phase 1 — 기반(Keychain, Upbit JWT, 도메인 모델)
- [x] Phase 2 — 업비트 네트워크 연동
- [x] Phase 3 — 환율(한국은행 ECOS + fallback)
- [x] Phase 4 — 증권사(토스 OAuth2 + KIS + NH placeholder)
- [x] Phase 5 — 분석 엔진(수익/배당/추이/비중) + Finnhub
- [x] Phase 6 — SwiftUI 화면 5탭 + 설정 + 위젯 + 알림 + DI
- [ ] 잔여(Xcode 필요) — `.xcodeproj` 구성, SwiftData 일별 스냅샷 영속화, 실제 키로 응답 스키마 검증, TestFlight 배포

---

## ⚠️ 알려진 한계 / 후속 작업

1. **증권사 응답 스키마**: 토스/KIS DTO 는 공개 문서 기반 추정치로, 실제 키 발급 후 필드 검증이 필요합니다(`⚠️` 주석 표기).
2. **일별 스냅샷**: 추이 탭의 시계열은 SwiftData 영속 스토어 연결이 남아 있습니다(현재 빈 시계열).
3. **Xcode 프로젝트**: 이 저장소는 코어 패키지 + 앱 소스로 구성되며, `.xcodeproj`/앱 타깃 구성은 Xcode 에서 추가합니다.
4. **TDD**: 모든 코어 로직은 테스트와 함께 작성되었으며 CI(macOS)에서 실행됩니다.
