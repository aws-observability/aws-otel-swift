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
    .package(url: "https://github.com/aws-observability/aws-otel-swift.git", from: "0.0.0")
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
  "aws": {
    "region": "us-west-2",
    "rumAppMonitorId": "your-app-monitor-id"
  },
  "applicationAttributes": {
    "application.version": "1.0.0"
  }
}
```

### Manual Initialization

You can also initialize the SDK manually. The SDK provides a builder pattern:

```swift
import AwsOpenTelemetryCore

// Create your configuration
let awsConfig = AwsConfig(region: "your-region", rumAppMonitorId: "your-app-monitor-id")
let config = AwsOpenTelemetryConfig(
    aws: awsConfig,
    applicationAttributes: ["application.version": "1.0.0"]
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

## Complete Configuration Example

The configuration follows this JSON schema:

```json
{
  "aws": {
    "region": "us-east-1",
    "rumAppMonitorId": "YOUR-RUM-APP-MONITOR-ID",
    "rumAlias": "YOUR-RUM-ALIAS",
    "cognitoIdentityPool": "YOUR-COGNITO-IDENTITY-POOL-ID"
  "exportOverride": {
    "logs": "http://10.0.2.2:4318/v1/logs",
    "traces": "http://10.0.2.2:4318/v1/traces"
  },
  "sessionTimeout": 1800,
  "sessionSampleRate": 1.0,
  "applicationAttributes": {
    "application.version": "1.0.0"
  },
  "debug": false,
  "telemetry": {
    "startup": { "enabled": true },
    "sessionEvents": { "enabled": true },
    "crash": { "enabled": true },
    "hang": { "enabled": true },
    "network": { "enabled": true }
    "view": { "enabled": true }
  },
}
```

### Manual Configuration Setup

You can also create the same configuration programmatically using the builder pattern:

```swift
import AwsOpenTelemetryCore

// Create AWS configuration
let awsConfig = AwsConfig(
    region: "us-east-1",
    rumAppMonitorId: "YOUR-RUM-APP-MONITOR-ID",
    rumAlias: "YOUR-RUM-ALIAS",
    cognitoIdentityPool: "YOUR-COGNITO-IDENTITY-POOL-ID"
)

// Create export override configuration
let exportOverride = ExportOverride(
    logs: "http://10.0.2.2:4318/v1/logs",
    traces: "http://10.0.2.2:4318/v1/traces"
)

// Create telemetry configuration
let telemetryConfig = TelemetryConfig()
    .withStartup(enabled: true)
    .withSessionEvents(enabled: true)
    .withCrash(enabled: true)
    .withHang(enabled: true)
    .withNetwork(enabled: true)
    .withView(enabled: true)

// Create complete configuration
let config = AwsOpenTelemetryConfig(
    aws: awsConfig,
    exportOverride: exportOverride,
    sessionTimeout: 1800,
    sessionSampleRate: 1.0,
    applicationAttributes: ["application.version": "1.0.0"],
    debug: false,
    telemetry: telemetryConfig
)

// Initialize the SDK
do {
    try AwsOpenTelemetryRumBuilder.create(config: config).build()
} catch {
    print("Error initializing SDK: \(error)")
}
```

## Instrumentation

The AWS OpenTelemetry Swift SDK provides automatic instrumentation for various iOS application components. Each instrumentation can be individually enabled or disabled through the telemetry configuration.

### Available Instrumentations

| Instrumentation    | Description                                                 | Documentation                                                                        |
| ------------------ | ----------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Network**        | Automatic HTTP request tracing for URLSession               | [Network README](Sources/AwsOpenTelemetryCore/Network/README.md)                     |
| **Crashes**        | Crash reporting using MetricKit MXCrashDiagnostic           | [Crashes README](Sources/AwsOpenTelemetryCore/MetricKit/README.md#crashes)           |
| **Hangs**          | Application hang detection using MetricKit MXHangDiagnostic | [Hangs README](Sources/AwsOpenTelemetryCore/MetricKit/README.md#hangs)               |
| **View Tracking**  | Automatic view instrumentation for UIKit and SwiftUI        | [UIKitView README](Sources/AwsOpenTelemetryCore/AutoInstrumentation/UIKit/README.md) |
| **Session Events** | Session lifecycle tracking with start/end events            | [Sessions README](Sources/AwsOpenTelemetryCore/Sessions/README.md)                   |

### Configuration Options

#### AwsConfig

| Field               | Type   | Required | Default | Description                                                                                                                                                                                                                                                                                                                      |
| ------------------- | ------ | -------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| region              | String | Yes      | -       | AWS region where the RUM service is deployed                                                                                                                                                                                                                                                                                     |
| rumAppMonitorId     | String | Yes      | -       | Unique identifier for the RUM App Monitor                                                                                                                                                                                                                                                                                        |
| rumAlias            | String | No       | nil     | Adds an alias to all requests. It will be compared to the rum:alias service context key in the resource based policy attached to a RUM app monitor. See public docs for using an alias with a [RUM resource based policy](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM-resource-policies.html). |
| cognitoIdentityPool | String | No       | nil     | Cognito Identity Pool ID for authentication                                                                                                                                                                                                                                                                                      |

#### ExportOverride

| Field  | Type   | Required | Default | Description                                                                                                                               |
| ------ | ------ | -------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| logs   | String | No       | nil     | Custom endpoint for log exports. When nil, uses AWS CloudWatch RUM OTLP endpoint `https://dataplane.rum.${region}.amazonaws.com/v1/rum`   |
| traces | String | No       | nil     | Custom endpoint for trace exports. When nil, uses AWS CloudWatch RUM OTLP endpoint `https://dataplane.rum.${region}.amazonaws.com/v1/rum` |

#### Root Configuration

| Field                 | Type    | Required | Default | Description                                                       |
| --------------------- | ------- | -------- | ------- | ----------------------------------------------------------------- |
| sessionTimeout        | Number  | No       | 1800    | The duration (in seconds) after which an inactive session expires |
| sessionSampleRate     | Number  | No       | 1.0     | Session sample rate from 0.0 to 1.0                               |
| applicationAttributes | Object  | No       | nil     | Key-value pairs for application metadata                          |
| debug                 | Boolean | No       | false   | Flag to enable debug logging                                      |

#### TelemetryConfig

| Field         | Type   | Required | Default             | Description                                                                                                                                                                                               |
| ------------- | ------ | -------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| startup       | Object | No       | { "enabled": true } | Generate MetricKit `MXAppLaungDiagnostic` as log records.                                                                                                                                                 |
| sessionEvents | Object | No       | { "enabled": true } | Creates `session.start` and `session.end` as log records according to OpenTelemetry Semantic Convention. As an ADOT-Swift extension, `session.end` also includes `duration` and `end_time`.               |
| crash         | Object | No       | { "enabled": true } | Generate MetricKit `MXCrashDiagnostic` as log records.                                                                                                                                                    |
| network       | Object | No       | { "enabled": true } | Generate spans of URLSession HTTP requests directly from OTel Swift's implementation of URLSessionInstrumentation. HTTP requests to the logs and spans endpoints are ignored to avoid infinite recursion. |
| hang          | Object | No       | { "enabled": true } | Generate MetricKit `MXHangDiagnostic` as log records.                                                                                                                                                     |
| view          | Object | No       | { "enabled": true } | Create spans from views created with UIKit and SwiftUI.                                                                                                                                                   |

**Note**: The `telemetry` section is optional in JSON configuration. If not provided, all telemetry features will be enabled by default.

## Testing

### Unit Tests

This project includes comprehensive test suites. For detailed testing instructions, troubleshooting, and contributor guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md#testing).

**Quick Test Command:**

```bash
swift test # macOS
make test-ios # iOS
make test-tvos # tvOS
make test-watchos # watchOS
make test-visionos # visionOS
```

**Test Coverage:**

```bash
# Run tests with coverage analysis (requires 70% repository, 80% PR changes)
make check-coverage # macOS
```

### Contract Tests
Contract tests require the following two steps:
1. Run the otel-collector locally.

This can be done using Docker: 

```bash
cd ./Tests/ContractTests/MockCollector
docker compose up
cd ../../..
```

Or without Docker by manually downloading the otel-collector (to emulate the Github Actions workflow): 

```bash
cd ./Tests/ContractTests/MockCollector
curl --proto '=https' --tlsv1.2 -fOL https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.133.0/otelcol_0.133.0_darwin_arm64.tar.gz
tar -xvf otelcol_0.133.0_darwin_arm64.tar.gz
cd ../../..
```


2. Use the UITests framework using XCUIApplication to tap buttons on the sample app and generate data.

Commands to generate contract test data: 

```bash
cd ./Examples/SimpleAwsDemo/SimpleAwsDemo.xcodeproj
make contract-test-generate-data-ios
cd ../../..
```

3. Run the following command to make sure that `logs.txt` and `traces.txt` were generated successfully: 

```bash
ls -al /tmp/otel-swift-collector
```

4. Run the unit test plan `ContractTestPlan` to read the generated data and validate the spans and logs written to file. 

Command to run contract tests:

```bash
make contract-test-run-ios
```

### Performance Tests

To run programmatic performance tests (using the UITests framework), run the following commands:

- `SimpleAwsDemo`

```
cd ./Examples/SimpleAwsDemo
make performance-test-ios
```

- `BaselineSimpleAwsDemo`

```
cd ./Examples/BaselineSimpleAwsDemo
make performance-test-ios
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
