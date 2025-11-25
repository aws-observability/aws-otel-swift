# Authentication Guide

This guide covers authentication options for AWS Distro for OpenTelemetry Swift.

## Resource-Based Policy (Recommended)

The simplest approach uses a resource-based policy. This works with both **AwsOpenTelemetryAgent** and **AwsOpenTelemetryCore** modules and requires no credential management in your app.

### Setup

1. [Create a resource-based policy in your RUM app monitor](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM-resource-policies.html)
2. (OPTIONAL) Configure your app with the alias, if your policy requires it:

**Agent (zero-code)** - `aws_config.json`:
```jsonc
{
  "aws": {
    "region": "us-east-1",
    "rumAppMonitorId": "your-app-monitor-id",
    "rumAlias": "your-rum-alias" // OPTIONAL: if your policy has defined it
  },
  "otelResourceAttributes": {
    "service.name": "MyApplication",
    "service.version": "1.0.0"
  }
}
```

**Core (programmatic)**:
```swift
import AwsOpenTelemetryCore

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AwsOpenTelemetryRumBuilder.create(
            config: AwsOpenTelemetryConfig(
                aws: AwsConfig(
                    rumAppMonitorId: "your-app-monitor-id",
                    region: "us-east-1",
                    rumAlias: "your-rum-alias" // OPTIONAL: if your policy has defined it
                ),
                otelResourceAttributes: [
                    "service.name": "MyApplication",
                    "service.version": "1.0.0"
                ]
            )
        )?.build()
        return true
    }
}
```

## SigV4 Authentication (Manual Configuration)

For advanced use cases requiring custom credential management, use SigV4-signed exporters available in **AwsOpenTelemetryAuth** with **AwsOpenTelemetryCore**.

### Dependencies

Add `AwsOpenTelemetryAuth` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aws-observability/aws-otel-swift.git", .upToNextMajor(from: "1.0.0"))
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AwsOpenTelemetryCore", package: "aws-otel-swift"),
            .product(name: "AwsOpenTelemetryAuth", package: "aws-otel-swift")
        ]
    )
]
```

### Custom Credentials Provider

Implement the `CredentialsProviding` protocol to provide your own credential management:

```swift
import AwsCommonRuntimeKit
import AwsOpenTelemetryAuth

class CustomCredentialsProvider: CredentialsProviding {
    func getCredentials() async throws -> Credentials {
        // Your custom credential retrieval logic
        return try Credentials(
            accessKey: "your-access-key",
            secret: "your-secret-key",
            sessionToken: "your-session-token",
            expiration: Date().addingTimeInterval(3600)
        )
    }
}
```

### Basic Implementation

```swift
import AwsOpenTelemetryCore
import AwsOpenTelemetryAuth

class AppDelegate: UIResponder, UIApplicationDelegate {
    private func setupOpenTelemetry() async {
        let region = "us-east-1"
        let credentialsProvider = CustomCredentialsProvider()

        let spanExporter = try AwsSigV4SpanExporterBuilder()
            .setRegion(region: region)
            .setCredentialsProvider(credentialsProvider: credentialsProvider)
            .build()

        let logExporter = try AwsSigV4LogRecordExporterBuilder()
            .setRegion(region: region)
            .setCredentialsProvider(credentialsProvider: credentialsProvider)
            .build()

        AwsOpenTelemetryRumBuilder.create(
            config: AwsOpenTelemetryConfig(
                aws: AwsConfig(
                    rumAppMonitorId: "your-app-monitor-id",
                    region: region
                ),
                otelResourceAttributes: [
                    "service.name": "MyApplication",
                    "service.version": "1.0.0"
                ]
            )
        )?
        .addSpanExporterCustomizer { _ in spanExporter }
        .addLogRecordExporterCustomizer { _ in logExporter }
        .build()
    }
}
```
