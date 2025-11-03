# AwsOTelTraceView

This module is responsible for capturing the following telemetries:

1. **[View Lifecycle Spans](#view-lifecycle-spans)** - Reports spans for SwiftUI view lifecycle events including body evaluations, onAppear, and onDisappear events.

2. **[Time to First Appear](#time-to-first-appear)** - Reports spans measuring the time from view initialization to first appearance on screen.

Every SwiftUI trace contains four basic components:

```text
view (root span: init → onDisappear)
 ├── body (time spent preparing the render)
 ├── onAppear (timestamp of render, can be multiple)
 ├── timeToFirstAppear (duration from init to first appear)
 ├── onDisappear (disappear event)
 └── view.duration (duration from appear to disappear)
```

## Usage

### Option 1: View Extension

```swift
import AwsOpenTelemetryCore

HomeView()
    .awsOpenTelemetryTrace("HomeScreen")

// With string attributes
ProfileDetailView(user: user)
    .awsOpenTelemetryTrace("ProfileDetail",
                          attributes: ["user_id": user.id])

// With typed attributes
ProfileDetailView(user: user)
    .awsOpenTelemetryTrace("ProfileDetail", attributes: [
        "user_id": AttributeValue.string(user.id),
        "user_count": AttributeValue.int(users.count)
    ])
```

### Option 2: Wrapper View

```swift
import AwsOpenTelemetryCore

// Basic usage
AwsOTelTraceView("HomeScreen") {
    HomeView()
}

// With string attributes
AwsOTelTraceView("ProfileDetail",
      attributes: ["user_id": "12345"]) {
    ProfileDetailView(user: user)
}

// With typed attributes
AwsOTelTraceView("ProductList", attributes: [
    "user_id": AttributeValue.string(user.id),
    "user_count": AttributeValue.int(users.count),
    "is_premium": AttributeValue.bool(user.isPremium)
]) {
    ProductListView(products: products)
}
```

> **Note:** Both approaches use the same underlying implementation. The view extension is often more convenient for existing codebases.

## Best Practices

1. **Use meaningful view names**: Choose stable identifiers that will be useful in dashboards (e.g., "HomeScreen", "ProfileDetail", "CheckoutFlow")

2. **Apply to key screens**: Focus on performance-critical screens rather than every small component

3. **Add relevant attributes**: Include contextual information that helps with analysis:

   ```swift
   .awsOpenTelemetryTrace("ProductList", attributes: [
       "category": product.category,
       "item_count": "\(products.count)"
   ])
   ```

## Configuration

SwiftUI view instrumentation is automatically enabled when view telemetry is enabled in your configuration:

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

For manual initialization, you can configure SwiftUI view instrumentation through the main configuration:

```swift
import AwsOpenTelemetryCore

// Create configuration with SwiftUI view instrumentation enabled
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

- **Name**: `"software.amazon.opentelemetry.SwiftUIView"`

## View Lifecycle Spans

The instrumentation creates spans for SwiftUI view lifecycle events with the following hierarchy:

```
HomeScreen (root span: init → onDisappear)
├── HomeScreen.timeToFirstAppear (standalone span: init → first onAppear)
├── HomeScreen.body (child span - can be multiple)
├── HomeScreen.onAppear (child span)
└── HomeScreen.onDisappear (child span)
```

### Example View Lifecycle Spans

#### Body Span

```json
{
  "traceId": "8348f6c2548bf2f10a4469d78f8d9eb0",
  "spanId": "4b48262f439e43d3",
  "parentSpanId": "0222e86a98c9588b",
  "name": "body",
  "kind": 3,
  "startTimeUnixNano": "1756776424051590912",
  "endTimeUnixNano": "1756776424054149120",
  "attributes": [
    { "key": "view.body.count", "value": { "intValue": "1" } },
    { "key": "view.lifecycle", "value": { "stringValue": "body" } }
  ]
}
```

#### onAppear Span

```json
{
  "traceId": "fce798b929a1b3310844c34d17955782",
  "spanId": "080e8d46c03fa286",
  "parentSpanId": "6164f0f97c43e971",
  "name": "onAppear",
  "kind": 3,
  "startTimeUnixNano": "1756797932926310144",
  "endTimeUnixNano": "1756797932926902016",
  "attributes": [
    { "key": "view.appear.count", "value": { "intValue": "1" } },
    { "key": "view.lifecycle", "value": { "stringValue": "onAppear" } }
  ]
}
```

#### onDisappear Span

```json
{
  "traceId": "227255dca08d52d78b658d21c8605783",
  "spanId": "bf2dc0d27c73d719",
  "parentSpanId": "ec618dc707a4e5a0",
  "name": "onDisappear",
  "kind": 3,
  "startTimeUnixNano": "1756797936090154240",
  "endTimeUnixNano": "1756797936090276096",
  "attributes": [
    { "key": "view.disappear.count", "value": { "intValue": "1" } },
    { "key": "view.lifecycle", "value": { "stringValue": "onDisappear" } }
  ]
}
```

### View Lifecycle Span Attributes

| Span Type   | Attribute              | Type   | Description             | Example          |
| ----------- | ---------------------- | ------ | ----------------------- | ---------------- |
| Root        | `view.name`            | string | Name of the view        | `"HomeScreen"`   |
| Root        | `view.type`            | string | View framework type     | `"swiftui"`      |
| Body        | `view.body.count`      | int    | Body evaluation counter | `1`, `2`, `3`... |
| Body        | `view.lifecycle`       | string | Lifecycle phase         | `"body"`         |
| onAppear    | `view.lifecycle`       | string | Lifecycle phase         | `"onAppear"`     |
| onAppear    | `view.appear.count`    | int    | Appear event counter    | `1`, `2`, `3`... |
| onDisappear | `view.lifecycle`       | string | Lifecycle phase         | `"onDisappear"`  |
| onDisappear | `view.disappear.count` | int    | Disappear event counter | `1`, `2`, `3`... |

## Time to First Appear

A `TimeToFirstAppear` span is created on the first `onAppear` event to measure view initialization performance.

### Example Time to First Appear Span

```json
{
  "traceId": "387cd74b9b78e96e0a9d636fa7ea44a1",
  "spanId": "2c72e7f96125fde5",
  "parentSpanId": "",
  "name": "TimeToFirstAppear",
  "kind": 3,
  "startTimeUnixNano": "1757717180098257920",
  "endTimeUnixNano": "1757717180103122944",
  "attributes": [
    {
      "key": "user.id",
      "value": { "stringValue": "1CBF1932-6111-4C87-89A3-8CD7B971187B" }
    },
    { "key": "screen.name", "value": { "stringValue": "ProfileView" } },
    { "key": "view.lifecycle", "value": { "stringValue": "TimeToFirstAppear" } }
  ],
  "status": {}
}
```

### Time to First Appear Attributes

| Attribute        | Type   | Description                | Example               |
| ---------------- | ------ | -------------------------- | --------------------- |
| `view.lifecycle` | string | Lifecycle phase identifier | `"TimeToFirstAppear"` |

## Requirements

- iOS 13.0+, macOS 10.15+, tvOS 13.0+, watchOS 6.0+
- AWS OpenTelemetry Swift SDK properly initialized
- OpenTelemetry tracer provider configured
