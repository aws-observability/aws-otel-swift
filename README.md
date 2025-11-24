# AWS Distro for OpenTelemetry for Swift

AWS Distro for OpenTelemetry (ADOT) Swift is a redistribution of the [OpenTelemetry Swift](https://github.com/open-telemetry/opentelemetry-swift), configured with in-house instrumentations to use with [AWS CloudWatch Real User Monitoring](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM.html).

## Feature Support

### Available Platforms

At this time, we only officially support iOS 16+. However, we also have continuation integration in place for latest versions of macOS, tvOS, watchOS, and visionOS.

### Available Instrumentations

| Instrumentation    | Description                                                                                                 | Documentation                                                                   |
| ------------------ | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **App Launch**     | App launches (cold, warm, and pre-warm)                                                                     | [App Launch README](Sources/AwsOpenTelemetryCore/AppLaunch/README.md)           |
| **Crashes**        | Crashes with on-device symbolication in Apple format via [KSCrash](https://github.com/kstenerud/KSCrash)    | [Crashes](Sources/AwsOpenTelemetryCore/KSCrash/AwsKSCrashInstrumentation.swift) |
| **Hangs**          | Application hang detection with live stack traces                                                           | [Hangs](Sources/AwsOpenTelemetryCore/Hang/AwsHangInstrumentation.swift)         |
| **Network**        | Network requests (currently limited to [URLSession](https://developer.apple.com/documentation/foundation/)) | [Network README](Sources/AwsOpenTelemetryCore/Network/README.md)                |
| **UIKit**          | View instrumentation for UIKit                                                                              | [UIKitView README](Sources/AwsOpenTelemetryCore/UIKit/README.md)                |
| **SwiftUI**        | View instrumentation for SwiftUI                                                                            | [SwiftUI README](Sources/AwsOpenTelemetryCore/SwiftUI/README.md)                |
| **Session Events** | Session lifecycle tracking with start and end events                                                        | [Sessions README](Sources/AwsOpenTelemetryCore/Sessions/README.md)              |

### Available Metadata

| Metadata             | Attribute Name                                     | Description                                                                               |
| -------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Session IDs          | `session.id`                                       | UID for the current user session, which by default expires after 30 minutes of inactivity |
| User IDs (anonymous) | `user.id`                                          | Anonymous UID to enumerate the current user                                               |
| Screen names         | `screen.name`                                      | The name of the current screen                                                            |
| Battery usage        | `hw.battery.charge`                                | Battery level as percentage (0.0-1.0)                                                     |
| CPU usage            | `process.cpu.utilization`                          | CPU utilization ratio (0.0-8.0+)                                                          |
| Memory usage         | `process.memory.usage`                             | Memory usage in megabytes                                                                 |
| Device data          | `device.model`, `os.version`, etc.                 | Hardware and OS information                                                               |
| Network data         | `network.carrier`, `network.connection.type`, etc. | Network connectivity information                                                          |

## Getting Started

### Installation

#### Swift Package Manager (SPM)

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/aws-observability/aws-otel-swift.git", .upToNextMajor(from: "1.0.0"))
]
```

#### Cocoapods

At this time, Cocoapods distribution is not supported. Please open an issue to get this work prioritized.

### Zero-Code Initialization

Add `AwsOpenTelemetryAgent` to target dependencies. This will automatically setup the AWS OTel agent using `AwsOpenTelemetryCore` as a transitive dependency.

```swift
targets: [
    .target(
        name: "<your app target>",
        dependencies: [
            .product(name: "AwsOpenTelemetryAgent", package: "aws-otel-swift")
        ]
    )
]
```

Then add `aws_config.json` to your application bundle. See [AwsHackerNewsDemo](Examples/AwsHackerNewsDemo/AwsHackerNewsDemo/aws_config.json) for a complete example.

```json
{
  "aws": {
    "rumAppMonitorId": "<your app monitor id>",
    "region": "<your app monitor region>"
  },
  "otelResourceAttributes": {
    "service.name": "<your application name>",
    "service.version": "1.0.0"
  }
}
```

### Manual Initialization

Add `AwsOpenTelemetryCore` to package dependencies. This option is recommended if you would like to directly manage our dependency on OTel.

```swift
targets: [
    .target(
        name: "<your app target>",
        dependencies: [
            .product(name: "AwsOpenTelemetryCore", package: "aws-otel-swift")
        ]
    )
]
```

Initialize the ADOT OTel Agent in your AppDelegate

```swift
import AwsOpenTelemetryCore

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AwsOpenTelemetryRumBuilder.create(
            config: AwsOpenTelemetryConfig(
                aws: AwsConfig(
                    rumAppMonitorId: "<your app monitor id>",
                    region: "<your app monitor region>"
                ),
                otelResourceAttributes: [
                    "service.name": "<your application name>",
                    "service.version": "1.0.0"
                ]
            )
        )?.build()
        return true
    }
}
```

## Configuration

```jsonc
{
  "aws": {
    "region": "<your app monitor region",
    "rumAppMonitorId": "<your app monitor id>",
    "rumAlias": "<your app monitor alias" // if resource based policy requires alias
  },
  "exportOverride": {
    "logs": "http://localhost:3000/v1/logs", // custom logs otlp endpoint
    "traces": "http://localhost:3000/v1/traces" // custom traces otlp endpoint
  },
  "sessionTimeout": 1800, // in seconds (default 30 minutes)
  "sessionSampleRate": 1.0, // as ratio from 0.0 -> 1.0
  "otelResourceAttributes": {
    "service.version": "1.0.0", // optional
    "service.name": "<your app name>" // optional
  },
  "telemetry": {
    "startup": { "enabled": true },
    "sessionEvents": { "enabled": true },
    "crash": { "enabled": true },
    "hang": { "enabled": true },
    "network": { "enabled": true },
    "view": { "enabled": true }
  },
  "debug": false // [for dev only] locally print info/warn/debug logs
}
```

### Authentication

For advanced authentication scenarios, you can implement custom identity providers using the `AwsOpenTelemetryAuth` module:

```swift
import AwsOpenTelemetryCore
import AwsOpenTelemetryAuth

class CustomIdentityProvider: CredentialsProviding {
    func getCredentials() async throws -> Credentials {
        // Your custom credential logic here
        return Credentials(...)
    }
}

// Create SigV4 exporters (uses default AWS RUM regional endpoints)
let customProvider = CustomIdentityProvider()
let sigV4SpanExporter = AwsSigV4SpanExporter(
    region: "us-east-1",
    credentialsProvider: customProvider
)
let sigV4LogExporter = AwsSigV4LogRecordExporter(
    region: "us-east-1",
    credentialsProvider: customProvider
)

// Add to agent builder
AwsOpenTelemetryRumBuilder.create(config: config)?
    .addSpanExporterCustomizer { _ in sigv4SpanExporter }
    .addLogRecordExporterCustomizer { _ in sigv4LogExporter }
    .build()
```

See the [AwsOpenTelemetryAuth README](Sources/AwsOpenTelemetryAuth/README.md) for complete examples including Cognito Identity Pool integration.

#### Root Configuration

| Field                  | Type                 | Required | Default     | Description                                                                                    |
| ---------------------- | -------------------- | -------- | ----------- | ---------------------------------------------------------------------------------------------- |
| aws                    | `AwsConfig`          | Yes      | nil         | AWS service configuration settings (see AwsConfig section)                                     |
| exportOverride         | `AwsExportOverride`  | No       | nil         | Export endpoint overrides for custom logs and traces endpoints (see AwsExportOverride section) |
| sessionTimeout         | `Int`                | No       | 30 \* 60    | Session timeout in seconds. When nil, uses default value                                       |
| sessionSampleRate      | `Double`             | No       | 1.0         | Session sample rate from 0.0 to 1.0. When nil, uses default value                              |
| otelResourceAttributes | `Object`             | No       | nil         | Key-value pairs for resource metadata, which are added as resource attributes                  |
| telemetry              | `AwsTelemetryConfig` | No       | all enabled | Telemetry feature configuration settings (see AwsTelemetryConfig section)                      |
| debug                  | `Boolean`            | No       | false       | Flag to enable local logging for debugging purposes.                                           |

#### AwsConfig

| Field           | Type   | Required | Default | Description                                                                                                                                                                                                                                                                                                                      |
| --------------- | ------ | -------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| region          | String | Yes      | -       | AWS region where the RUM service is deployed                                                                                                                                                                                                                                                                                     |
| rumAppMonitorId | String | Yes      | -       | Unique identifier for the RUM App Monitor                                                                                                                                                                                                                                                                                        |
| rumAlias        | String | No       | nil     | Adds an alias to all requests. It will be compared to the rum:alias service context key in the resource based policy attached to a RUM app monitor. See public docs for using an alias with a [RUM resource based policy](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM-resource-policies.html). |

#### AwsExportOverride

| Field  | Type   | Required | Default | Description                                                                                                                               |
| ------ | ------ | -------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| logs   | String | No       | nil     | Custom endpoint for log exports. When nil, uses AWS CloudWatch RUM OTLP endpoint `https://dataplane.rum.${region}.amazonaws.com/v1/rum`   |
| traces | String | No       | nil     | Custom endpoint for trace exports. When nil, uses AWS CloudWatch RUM OTLP endpoint `https://dataplane.rum.${region}.amazonaws.com/v1/rum` |

#### AwsTelemetryConfig

| Field         | Type   | Required | Default             | Description                                                                                                                                                                                               |
| ------------- | ------ | -------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| startup       | Object | No       | { "enabled": true } | Generate app launch diagnostic as log records.                                                                                                                                                            |
| sessionEvents | Object | No       | { "enabled": true } | Creates `session.start` and `session.end` as log records according to OpenTelemetry Semantic Convention. As an ADOT-Swift extension, `session.end` also includes `duration` and `end_time`.               |
| crash         | Object | No       | { "enabled": true } | Generate crash diagnostic as log records.                                                                                                                                                                 |
| network       | Object | No       | { "enabled": true } | Generate spans of URLSession HTTP requests directly from OTel Swift's implementation of URLSessionInstrumentation. HTTP requests to the logs and spans endpoints are ignored to avoid infinite recursion. |
| hang          | Object | No       | { "enabled": true } | Generate hang diagnostic as log records.                                                                                                                                                                  |
| view          | Object | No       | { "enabled": true } | Create spans from views created with UIKit and SwiftUI.                                                                                                                                                   |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed testing instructions, development setup, and contributor guidelines.

## License

This project is licensed under the Apache-2.0 License.
