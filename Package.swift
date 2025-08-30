// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "aws-otel-swift",
  platforms: [
    .iOS(.v13), // officially only supporting iOS
    .macOS(.v12),
    .tvOS(.v13),
    .watchOS(.v6)
    // .visionOS(.v1) // not supported by aws-sdk-swift
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(name: "AwsOpenTelemetryCore", targets: ["AwsOpenTelemetryCore"]),
    .library(name: "AwsOpenTelemetryAgent", targets: ["AwsOpenTelemetryAgent"]),
    .library(name: "AwsOpenTelemetryAuth", targets: ["AwsOpenTelemetryAuth"])
  ],
  dependencies: [
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "1.14.0"),
    .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.3.32"),
    .package(url: "https://github.com/smithy-lang/smithy-swift", from: "0.134.0"),
    .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "AwsOpenTelemetryCore",
      dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
        .product(name: "StdoutExporter", package: "opentelemetry-swift"),
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
        .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift")
      ],
      exclude: ["AutoInstrumentation/UIKit/README.md", "Sessions/README.md"]
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
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
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
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
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
    ),
    .testTarget(
      name: "AwsOpenTelemetryAuthTests",
      dependencies: ["AwsOpenTelemetryAuth"]
    ),
    .testTarget(
      name: "AwsOpenTelemetryAgentTests",
      dependencies: ["AwsOpenTelemetryCore", "AwsOpenTelemetryAgent"]
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
