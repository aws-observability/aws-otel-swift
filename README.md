# AWS OpenTelemetry for Swift

A Swift package for AWS OpenTelemetry that supports automatic initialization when imported into an iOS application.

## Development Setup

### Git Hooks

This repository uses Git hooks to ensure code quality. To set up the hooks:

```bash
./scripts/setup-git-hooks.sh
```

This will install pre-commit hooks that automatically format and lint Swift code using SwiftFormat and SwiftLint.

## Features

- Zero-code instrumentation via automatic initialization
- Support for custom initialization and configuration
- Flexible customization of exporters and providers
- Configuration via JSON file or programmatically
- Thread-safe initialization

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/aws-observability/aws-otel-swift.git", from: "1.0.0")
]
```

## Usage

### Automatic Initialization

The SDK will automatically initialize when imported into your app. It will look for a file named `aws_config.json` in your app bundle.

Example `aws_config.json`:

```json
{
  "version": "1.0.0",
  "rum": {
    "region": "us-west-2",
    "appMonitorId": "your-app-monitor-id"
  },
  "application": {
    "applicationVersion": "1.0.0"
  }
}
```

### Manual Initialization

You can also initialize the SDK manually:

```swift
import AwsOpenTelemetryCore

// Initialize with default config file
AwsOpenTelemetryAgent.shared.initializeWithJsonConfig()

// Or initialize with custom config
let config = AwsOpenTelemetryConfig(
    rum: RumConfig(region: "us-west-2", appMonitorId: "your-app-monitor-id"),
    application: ApplicationConfig(applicationVersion: "1.0.0")
)
AwsOpenTelemetryAgent.shared.initialize(config: config)
```

### Advanced Customization

The SDK provides a builder pattern for advanced customization:

```swift
import AwsOpenTelemetryCore
import OpenTelemetryApi
import OpenTelemetrySdk

// Create your configuration
let config = AwsOpenTelemetryConfig(
    rum: RumConfig(region: "us-west-2", appMonitorId: "your-app-monitor-id"),
    application: ApplicationConfig(applicationVersion: "1.0.0")
)

// Create a builder, customize it, and build in one go
do {
    try AwsOpenTelemetryRumBuilder.create(config: config)
        .addSpanExporterCustomizer { exporter in
            // Add your custom span exporter or modify the existing one
            return MultiSpanExporter(spanExporters: [
                exporter,
                YourCustomSpanExporter()
            ])
        }
        .addLogRecordExporterCustomizer { exporter in
            // Add your custom log exporter or modify the existing one
            return exporter
        }
        .addTracerProviderCustomizer { builder in
            // Customize the tracer provider
            return builder.add(spanProcessor: YourCustomSpanProcessor())
        }
        .build()
} catch AwsOpenTelemetryConfigError.alreadyInitialized {
    print("SDK is already initialized")
} catch {
    print("Error initializing SDK: \(error)")
}
```

## Thread Safety

The SDK ensures thread safety by preventing multiple initializations. Whether you use the `AwsOpenTelemetryAgent.shared.initialize()` method or the builder pattern, the SDK will only allow initialization once. Subsequent attempts to initialize will throw an `AwsOpenTelemetryConfigError.alreadyInitialized` error.

## Initialization Process

The SDK uses the Objective-C runtime's `+load` method to perform synchronous initialization during class loading. This approach ensures that:

1. Instrumentation is set up before any application code runs
2. All network requests are properly monitored from the very beginning
3. No race conditions occur between initialization and early network requests

The synchronous initialization has minimal impact on app startup time while providing complete coverage of all application activities.

## Configuration Schema

The configuration follows this JSON schema:

```json
{
  "version": "1.0.0",
  "rum": {
    "region": "aws-region",
    "appMonitorId": "app-monitor-id",
    "overrideEndpoint": {
      "logs": "optional-logs-endpoint",
      "traces": "optional-traces-endpoint"
    },
    "debug": false
  },
  "application": {
    "applicationVersion": "app-version"
  }
}
```

### Configuration Options

#### RumConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| region | String | Yes | AWS region where the RUM service is deployed |
| appMonitorId | String | Yes | Unique identifier for the RUM App Monitor |
| overrideEndpoint | Object | No | Optional endpoint overrides for the RUM service |
| debug | Boolean | No | Flag to enable debug logging (defaults to false) |

#### ApplicationConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| applicationVersion | String | Yes | Version of the application being monitored |

## License

This project is licensed under the Apache-2.0 License.
