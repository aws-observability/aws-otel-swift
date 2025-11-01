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
    .library(name: "AwsOpenTelemetryAgent", targets: ["AwsOpenTelemetryAgent"])
  ],
  dependencies: [
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", from: "2.2.0"),
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "2.2.0"),
    .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"),
    .package(url: "https://github.com/kstenerud/KSCrash.git", .upToNextMajor(from: "2.4.0")),
    .package(url: "https://github.com/microsoft/plcrashreporter.git", from: "1.11.2")
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
      exclude: ["Sessions/README.md", "MetricKit/README.md", "Network/README.md", "User/README.md", "GlobalAttributes/README.md", "UIKit/README.md", "AppLaunch/README.md", "SwiftUI/README.md"]
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
      name: "TestUtils",
      dependencies: [
        "AwsOpenTelemetryCore",
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
      ],
      path: "Tests/TestUtils"
    ),
    .testTarget(
      name: "AwsOpenTelemetryCoreTests",
      dependencies: [
        "AwsOpenTelemetryCore",
        "TestUtils",
        .product(name: "Atomics", package: "swift-atomics")
      ]
    )
    // .testTarget(
    //   name: "ContractTests",
    //   dependencies: ["AwsOpenTelemetryCore", "AwsOpenTelemetryAgent"],
    //   path: "Tests/ContractTests",
    //   exclude: ["MockCollector"],
    //   sources: ["NetworkTests.swift", "UITests.swift", "Sources/OTLPResolver.swift", "Sources/OTLPParser"]
    // )
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
