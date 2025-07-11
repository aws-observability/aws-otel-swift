# AWS Distro for OpenTelemetry - Instrumentation for Swift

A Swift package for AWS OpenTelemetry.

## Introduction

This repository is a redistribution of the [OpenTelemetry Swift SDK](https://github.com/open-telemetry/opentelemetry-swift), preconfigured for use with AWS services. Please check out the upstream repository too to get a better understanding of the underlying internals. The upstream repository is still maturing so much of the instrumentation has been built in this repository. In addition, this also supports integration with CloudWatch RUM.

We provide a Swift library that can be consumed within any Native iOS application using iOS 16+ (TODO: Update once version is finalized). We build convenience functions to onboard your application with OpenTelemetry and start ingesting telemetry into your CloudWatch RUM Application Monitors.

## Installation

### Xcode

1. Go to File > Add Package Dependencies...
2. Search for the ADOT Swift SDK package url (`https://github.com/aws-observability/aws-otel-swift`) and click the "Add Package" button.
3. Add the `AwsOpenTelemetryCore` Package Product to your application's target.

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

### CocoaPods (TODO: Update once Pod specs are created and tested)

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

| Error Case           | Description                                                 |
| -------------------- | ----------------------------------------------------------- |
| `alreadyInitialized` | Thrown when attempting to initialize the SDK multiple times |

### AwsOpenTelemetryAuthError

Authentication-related errors that may occur when working with AWS Cognito Identity:

| Error Case         | Description                                         | Common Causes                                                            |
| ------------------ | --------------------------------------------------- | ------------------------------------------------------------------------ |
| `noIdentityId`     | Failed to retrieve Cognito Identity ID              | Identity pool misconfiguration, incorrect region, network issues         |
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
    "debug": false,
    "alias": "optional-alias"
  },
  "application": {
    "applicationVersion": "app-version"
  },
  "telemetry": {
    "isUiKitViewInstrumentationEnabled": true
  }
}
```

### Configuration Options

#### RumConfig

| Field            | Type    | Required | Description                                                                                                                                        |
| ---------------- | ------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| region           | String  | Yes      | AWS region where the RUM service is deployed                                                                                                       |
| appMonitorId     | String  | Yes      | Unique identifier for the RUM App Monitor                                                                                                          |
| overrideEndpoint | Object  | No       | Optional endpoint overrides for the RUM service                                                                                                    |
| debug            | Boolean | No       | Flag to enable debug logging (defaults to false)                                                                                                   |
| alias            | String  | No       | Adds an alias to all requests. It will be compared to the rum:alias service context key in the resource based policy attached to a RUM app monitor |
| sessionTimeout   | Number  | No       | The duration (in seconds) after which an inactive session expires. Default 1800 seconds (30 minutes)                                               |

#### ApplicationConfig

| Field              | Type   | Required | Description                                |
| ------------------ | ------ | -------- | ------------------------------------------ |
| applicationVersion | String | Yes      | Version of the application being monitored |

#### TelemetryConfig

| Field                             | Type    | Required | Description                                                               |
| --------------------------------- | ------- | -------- | ------------------------------------------------------------------------- |
| isUiKitViewInstrumentationEnabled | Boolean | No       | Enable automatic UIKit view controller instrumentation (defaults to true) |

**Note**: The `telemetry` section is optional in JSON configuration. If not provided, all telemetry features will be enabled by default.

## Testing

This project includes comprehensive test suites. For detailed testing instructions, troubleshooting, and contributor guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md#testing).

**Quick Test Command:**

```bash
xcodebuild test -scheme aws-otel-swift-Package -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Development Setup

### Git Hooks

This repository uses Git hooks to ensure code quality. For a quick setup, run:

```bash
./scripts/setup-all.sh
```

This will set up Git hooks and needed tools in one step.

For more details about the individual scripts and how to set them up separately, see the [scripts README](./scripts/README.md).

## License

This project is licensed under the Apache-2.0 License.
