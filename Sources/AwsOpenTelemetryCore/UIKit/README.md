# AwsUIKitViewInstrumentation

This module is responsible for capturing the following telemetries:

1. **[View Load Performance](#view-load-performance)** - Reports spans tracking complete UIViewController lifecycle from `viewDidLoad` → `viewDidAppear`.

2. **[View Visibility Duration](#view-visibility-duration)** - Reports spans measuring time from `viewDidAppear` → `viewDidDisappear`.

## Getting Started

UIKit view instrumentation is automatically enabled when view telemetry is enabled in your configuration:

```json
{
  "aws": {
    "region": "us-west-2",
    "rumAppMonitorId": "your-app-monitor-id"
  },
  "applicationAttributes": {
    "application.version": "1.0.0"
  },
  "telemetry": {
    "view": { "enabled": true } // enabled by default
  }
}
```

### Manual Instrumentation

For manual initialization, you can configure UIKit view instrumentation through the main configuration:

```swift
import AwsOpenTelemetryCore

// Create configuration with UIKit view instrumentation enabled
let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "your-app-monitor-id")
let config = AwsOpenTelemetryConfig(
    aws: awsConfig,
    applicationAttributes: ["application.version": "1.0.0"],
    telemetry: AwsTelemetryConfig.builder()
        .with(view: TelemetryFeature(enabled: true))
        .build()
)

// Initialize the SDK
try AwsOpenTelemetryRumBuilder.create(config: config).build()
```

### Instrumentation Scope

- **Name**: `"software.amazon.opentelemetry.UIKitView"`

## Customization

### Custom View Names

Provide user-friendly names for better observability:

```swift
class LoginViewController: UIViewController, AwsViewControllerCustomization {
  var customScreenName: String? { "Login Screen" }
  var shouldCaptureView: Bool { true }
}
```

### Opt-Out of Instrumentation

Disable instrumentation for specific view controllers:

```swift
class DebugViewController: UIViewController, AwsViewControllerCustomization {
  var shouldCaptureView: Bool { false } // Skip instrumentation
}
```

## View Load Performance

A `TimeToFirstAppear` span is created to measure the complete view loading lifecycle from `viewDidLoad` to `viewDidAppear`.

### Span Hierarchy

```
TimeToFirstAppear (Root Span - measures complete loading time)
├── viewDidLoad (Child Span)
├── viewWillAppear (Child Span)
├── viewIsAppearing (Child Span)
└── viewDidAppear (Child Span)
```

### Example View Load Span

```json
{
  "traceId": "8348f6c2548bf2f10a4469d78f8d9eb0",
  "spanId": "4b48262f439e43d3",
  "parentSpanId": "",
  "name": "TimeToFirstAppear",
  "kind": 3,
  "startTimeUnixNano": "1756776424051590912",
  "endTimeUnixNano": "1756776424054149120",
  "attributes": [
    { "key": "view.name", "value": { "stringValue": "Login Screen" } },
    { "key": "view.class", "value": { "stringValue": "LoginViewController" } }
  ]
}
```

### View Load Span Attributes

| Attribute    | Type   | Description               | Example                 |
| ------------ | ------ | ------------------------- | ----------------------- |
| `view.name`  | string | Display name for the view | `"Login Screen"`        |
| `view.class` | string | Actual class name         | `"LoginViewController"` |

## View Visibility Duration

A `view.duration` span is created to measure how long a view remains visible from `viewDidAppear` to `viewDidDisappear`.

### Example View Duration Span

```json
{
  "traceId": "8348f6c2548bf2f10a4469d78f8d9eb0",
  "spanId": "432d8e52ab894d5a",
  "parentSpanId": "",
  "name": "view.duration",
  "kind": 3,
  "startTimeUnixNano": "1756797932919669248",
  "endTimeUnixNano": "1756797932926310144",
  "attributes": [
    { "key": "view.name", "value": { "stringValue": "Login Screen" } },
    { "key": "view.class", "value": { "stringValue": "LoginViewController" } }
  ]
}
```

### View Duration Span Attributes

| Attribute    | Type   | Description               | Example                 |
| ------------ | ------ | ------------------------- | ----------------------- |
| `view.name`  | string | Display name for the view | `"Login Screen"`        |
| `view.class` | string | Actual class name         | `"LoginViewController"` |
