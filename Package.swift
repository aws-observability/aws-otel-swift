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
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(name: "AwsOpenTelemetryCore", targets: ["AwsOpenTelemetryCore"]),
    .library(name: "AwsOpenTelemetryAgent", targets: ["AwsOpenTelemetryAgent"]),
    .library(name: "AwsOpenTelemetryAuth", targets: ["AwsOpenTelemetryAuth"]),
    .library(name: "AwsOpenTelemetryUIKitInstrumentation", targets: ["AwsOpenTelemetryUIKitInstrumentation"])
  ],
  dependencies: [
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "1.14.0"),
    .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.3.32"),
    .package(url: "https://github.com/smithy-lang/smithy-swift", from: "0.134.0")
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
        "AwsOpenTelemetryUIKitInstrumentation"
      ]
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
      ]
    ),
    .target(
      name: "AwsOpenTelemetryUIKitInstrumentation",
      dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
      ],
      path: "Sources/Instrumentation/UIKit"
    ),
    .testTarget(
      name: "AwsOpenTelemetryTests",
      dependencies: ["AwsOpenTelemetryCore"]
    ),
    .testTarget(
      name: "AwsOpenTelemetryAuthTests",
      dependencies: ["AwsOpenTelemetryAuth"]
    ),
    .testTarget(
      name: "AwsOpenTelemetryUIKitInstrumentationTests",
      dependencies: ["AwsOpenTelemetryUIKitInstrumentation"],
      path: "Tests/UIKitInstrumentationTests"
    )
  ]
).addPlatformSpecific()

extension Package {
  func addPlatformSpecific() -> Self {
    #if canImport(Darwin)
      targets[0].dependencies
        .append(.product(name: "ResourceExtension", package: "opentelemetry-swift"))
      products.append(contentsOf: [
        .library(name: "AwsURLSessionInstrumentation", targets: ["AwsURLSessionInstrumentation"])
      ])
      targets.append(contentsOf: [
        .target(
          name: "AwsURLSessionInstrumentation",
          dependencies: [
            "AwsOpenTelemetryCore",
            .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
            .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift")
          ],
          path: "Sources/Instrumentation/"
        ),
        .testTarget(
          name: "AwsURLSessionInstrumentationTests",
          dependencies: ["AwsURLSessionInstrumentation"],
          path: "Tests/InstrumentationTests"
        )

      ])
    #endif
    return self
  }
}
