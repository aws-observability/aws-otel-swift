# AWS OpenTelemetry for Swift

A Swift package for AWS OpenTelemetry.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/aws-observability/aws-otel-swift.git", from: "1.0.0")
]
```

## Initialization

### Automatic Initialization

The SDK will automatically initialize when the "AwsOpenTelemetryAgent" module is imported into your app. It will look for a file named `aws_config.json` in your app bundle.

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

You can also initialize the SDK manually. The SDK provides a builder pattern:

```swift
import AwsOpenTelemetryCore

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

### Thread Safety
You should only import the "AwsOpenTelemetryAgent" module if you would like the agent to auto initialize. If you are manually initializing the SDK, you should **not** import the "AwsOpenTelemetryAgent" module. The SDK ensures thread safety by only allowing initialization once. Given the auto-initialization occurs early on during class loading, the manual initialization will throw an `AwsOpenTelemetryConfigError.alreadyInitialized` error.

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

## Development Setup

### Git Hooks

This repository uses Git hooks to ensure code quality. To set up the hooks:

```bash
./scripts/setup-git-hooks.sh
```

This will install pre-commit hooks that automatically format and lint Swift code using SwiftFormat and SwiftLint.

## License

This project is licensed under the Apache-2.0 License.
