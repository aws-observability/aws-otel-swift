// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "aws-otel-swift",
  platforms: [
    .iOS(.v13), // officially only supporting iOS v16+
    .macOS(.v12),
    .tvOS(.v13),
    .watchOS(.v6),
    .visionOS(.v1)
  ],
  products: [
    .library(name: "AwsOpenTelemetryCore", targets: ["AwsOpenTelemetryCore"]),
    .library(name: "AwsOpenTelemetryAgent", targets: ["AwsOpenTelemetryAgent"]),
    .library(name: "AwsOpenTelemetryAuth", targets: ["AwsOpenTelemetryAuth"])
  ],
  dependencies: [
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", from: "2.2.0"),
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "2.2.0"),
    .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.3.32"),
    .package(url: "https://github.com/smithy-lang/smithy-swift", from: "0.134.0"),
    .package(url: "https://github.com/kstenerud/KSCrash.git", .upToNextMajor(from: "2.4.0")),
    .package(url: "https://github.com/microsoft/plcrashreporter.git", from: "1.11.2") // only used for live stack trace collection, not crash reporting
  ],
  targets: [
    .target(
      name: "AwsOpenTelemetryCore",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        .product(name: "StdoutExporter", package: "opentelemetry-swift-core"),
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
        .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
        .product(name: "Installations", package: "KSCrash"),
        .product(name: "CrashReporter", package: "plcrashreporter", condition: .when(platforms: [.iOS, .macOS, .tvOS, .visionOS]))
      ],
      exclude: ["Sessions/README.md", "Network/README.md", "User/README.md", "GlobalAttributes/README.md", "UIKit/README.md", "AppLaunch/README.md", "SwiftUI/README.md"]
    ),
    .target(
      name: "AwsOpenTelemetryAgent",
      dependencies: ["AwsOpenTelemetryCore"],
      publicHeadersPath: "include",
      cSettings: [
        .headerSearchPath("include")
      ],
      linkerSettings: [
        .linkedFramework("Foundation")
      ]
    ),
    .target(
      name: "AwsOpenTelemetryAuth",
      dependencies: [
        "AwsOpenTelemetryCore",
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
        .product(name: "SmithyIdentity", package: "smithy-swift"),
        .product(name: "SmithyHTTPAuth", package: "smithy-swift"),
        .product(name: "SmithyHTTPAuthAPI", package: "smithy-swift"),
        .product(name: "SmithyHTTPAPI", package: "smithy-swift"),
        .product(name: "Smithy", package: "smithy-swift"),
        .product(name: "AWSSDKHTTPAuth", package: "aws-sdk-swift"),
        .product(name: "AWSCognitoIdentity", package: "aws-sdk-swift")
      ],
      exclude: ["README.md"]
    ),
    .target(
      name: "TestUtils",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
      ],
      path: "Tests/TestUtils"
    ),
    .testTarget(
      name: "AwsOpenTelemetryCoreTests",
      dependencies: [
        "AwsOpenTelemetryCore",
        "TestUtils"
      ]
    ),
    .testTarget(
      name: "AwsOpenTelemetryAuthTests",
      dependencies: ["AwsOpenTelemetryAuth"]
    ),
    .testTarget(
      name: "ContractTests",
      dependencies: ["AwsOpenTelemetryCore"],
      path: "Tests/ContractTests"
    )
  ]
).addPlatformSpecific()

extension Package {
  func addPlatformSpecific() -> Self {
    #if canImport(Darwin)
      targets[0].dependencies
        .append(.product(name: "ResourceExtension", package: "opentelemetry-swift"))
    #endif
    return self
  }
}
