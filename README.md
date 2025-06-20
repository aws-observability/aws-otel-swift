# AWS Distro for OpenTelemetry - Instrumentation for Swift

A Swift package for AWS OpenTelemetry.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
// In your package dependencies:
dependencies: [
    .package(url: "https://github.com/aws-observability/aws-otel-swift.git", from: "1.0.0")
]

// In your target dependencies:
targets: [
    .target(
        name: "YourAppTarget",
        dependencies: [ 
            .product(name: "AwsOpenTelemetryCore", package: "aws-otel-swift")
            
            // Only for automatic initialization
            .product(name: "AwsOpenTelemetryAgent", package: "aws-otel-swift"),
            
            // Other dependencies...
        ]
    )
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

## Error Handling

The SDK defines several error types to help you handle different failure scenarios:

### AwsOpenTelemetryConfigError

| Error Case | Description |
|------------|-------------|
| `alreadyInitialized` | Thrown when attempting to initialize the SDK multiple times |

### AwsOpenTelemetryAuthError

Authentication-related errors that may occur when working with AWS Cognito Identity:

| Error Case | Description | Common Causes |
|------------|-------------|---------------|
| `noIdentityId` | Failed to retrieve Cognito Identity ID | Identity pool misconfiguration, incorrect region, network issues |
| `credentialsError` | Failed to retrieve AWS credentials for the identity | IAM role misconfiguration, insufficient permissions, invalid identity ID |

Example error handling:

```swift
import AwsOpenTelemetryAuth

do {
    let credentials = try await provider.getCredentials()
    // Use credentials...
} catch AwsOpenTelemetryAuthError.noIdentityId {
    print("Failed to retrieve Cognito Identity ID - check your identity pool configuration")
} catch AwsOpenTelemetryAuthError.credentialsError {
    print("Failed to retrieve AWS credentials - check your IAM role configuration")
} catch {
    print("Unexpected error: \(error)")
}
```

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
| alias | String | No | Adds an alias to all requests. It will be compared to the rum:alias service context key in the resource based policy attached to a RUM app monitor |

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
