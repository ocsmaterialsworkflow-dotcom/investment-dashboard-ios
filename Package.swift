// swift-tools-version: 5.9
import PackageDescription

// InvestAppCore: 플랫폼 의존성이 낮은 순수 로직(보안·인증·도메인·네트워크 모델)을
// SwiftUI 앱 타깃에서 분리해 TDD / CI 에서 단독 빌드·테스트할 수 있게 한다.
// SwiftUI 앱(InvestApp)은 Xcode 프로젝트에서 이 패키지를 의존성으로 가져다 쓴다.
let package = Package(
    name: "InvestAppCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14) // 테스트를 macOS 에서 실행하기 위함 (CryptoKit/Security 사용 가능)
    ],
    products: [
        .library(name: "InvestAppCore", targets: ["InvestAppCore"])
    ],
    targets: [
        .target(
            name: "InvestAppCore",
            path: "Sources/InvestAppCore"
        ),
        .testTarget(
            name: "InvestAppCoreTests",
            dependencies: ["InvestAppCore"],
            path: "Tests/InvestAppCoreTests"
        )
    ]
)
