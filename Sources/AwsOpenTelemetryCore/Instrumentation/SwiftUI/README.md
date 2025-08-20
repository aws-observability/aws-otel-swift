# AWS OpenTelemetry SwiftUI View Performance Tracing

This module provides SwiftUI components for automatically capturing view load performance metrics using OpenTelemetry tracing.

## Features

The tracing wrapper captures view lifecycle events with the following span hierarchy:

**Root span** with child spans for:
- **body** (can be multiple - each time SwiftUI re-evaluates the view's body)
- **.onAppear** (when the view appears on screen)
- **.onDisappear** (when the view disappears from screen)

## File Structure

```
SwiftUI/
├── AwsOpenTelemetryTraceView.swift     # Main wrapper view implementation
├── View+AwsOpenTelemetryTrace.swift    # SwiftUI View extensions
├── ViewTraceState.swift                # Internal state management
└── README.md                           # This documentation
```

## Configuration

### Enabling/Disabling Instrumentation

SwiftUI view instrumentation can be controlled through the main AWS OpenTelemetry configuration:

#### JSON Configuration

```json
{
  "version": "1.0.0",
  "rum": {
    "region": "us-west-2",
    "appMonitorId": "your-app-monitor-id"
  },
  "application": {
    "applicationVersion": "1.0.0"
  },
  "telemetry": {
    "isSwiftUIViewInstrumentationEnabled": true
  }
}
```

#### Programmatic Configuration

```swift
import AwsOpenTelemetryCore

// Create configuration with SwiftUI instrumentation enabled
let config = AwsOpenTelemetryConfig(
  rum: RumConfig(region: "us-west-2", appMonitorId: "your-app-monitor-id"),
  application: ApplicationConfig(applicationVersion: "1.0.0"),
  telemetry: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
)

// Set the configuration
AwsOpenTelemetryConfigManager.shared.setConfig(config)

// Or disable SwiftUI instrumentation
let disabledConfig = AwsOpenTelemetryConfig(
  rum: RumConfig(region: "us-west-2", appMonitorId: "your-app-monitor-id"),
  application: ApplicationConfig(applicationVersion: "1.0.0"),
  telemetry: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false)
)
```

### Instrumentation Name

All view instrumentation (both SwiftUI and UIKit) uses the unified instrumentation name:
- **Instrumentation Name**: `"aws-opentelemetry-swift"`
- **Instrumentation Version**: `"1.0.0"`

### Zero Overhead When Disabled

When `isSwiftUIViewInstrumentationEnabled` is `false`:
- All tracing calls become no-ops
- No spans are created
- No OpenTelemetry overhead
- Views render normally without any performance impact

## Usage

### Option 1: Wrapper View

```swift
import AwsOpenTelemetryCore

AwsOpenTelemetryTraceView("HomeScreen") {
    HomeView()
}

// With attributes
AwsOpenTelemetryTraceView("ProfileDetail", 
                         attributes: ["user_id": "12345"]) {
    ProfileDetailView(user: user)
}
```

### Option 2: View Extension (Recommended)

```swift
import AwsOpenTelemetryCore

HomeView()
    .awsOpenTelemetryTrace("HomeScreen")

// With attributes
ProfileDetailView(user: user)
    .awsOpenTelemetryTrace("ProfileDetail", 
                          attributes: ["user_id": user.id])
```

> **Note:** Both approaches use the same underlying `AwsOpenTelemetryTraceView` implementation, so there's no performance difference. The view extension is often more convenient for existing codebases.

## Span Structure

The tracing creates the following span hierarchy:

```
HomeScreen (root span: init → onDisappear)
├── HomeScreen.body (child span - can be multiple)
├── HomeScreen.onAppear (child span)
└── HomeScreen.onDisappear (child span)
```

### Span Details

- **`{viewName}`**: Root span measuring complete view lifecycle
  - Start: View initialization time
  - End: `onDisappear` callback time
  - Span Kind: `client`
  - Attributes: `view.name`, `view.type=swiftui`, plus custom attributes

- **`{viewName}.body`**: Child spans for each body evaluation
  - Start: When SwiftUI begins evaluating the view's body
  - End: When body evaluation completes
  - Span Kind: `client`
  - Attributes: `view.body.evaluation` (counter), `view.lifecycle=body`

- **`{viewName}.onAppear`**: Child span for onAppear event
  - Start: `onAppear` time
  - End: Immediately (point-in-time event)
  - Span Kind: `client`
  - Attributes: `view.lifecycle=onAppear`, `view.appear.count`

- **`{viewName}.onDisappear`**: Child span for onDisappear event
  - Start: `onDisappear` time
  - End: Immediately (point-in-time event)
  - Span Kind: `client`
  - Attributes: `view.lifecycle=onDisappear`, `view.disappear.count`

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

4. **Avoid on frequently re-rendered views**: Don't apply to views that re-render frequently as it may impact performance

## Architecture

### ViewTraceState

The `ViewTraceState` class uses reference semantics to persist state across SwiftUI updates without triggering re-renders. This is crucial for preventing infinite update cycles.

**Key Properties:**
- `initializationTime`: Captured when the view is first created
- `timeToRenderSpan`: Tracks the main performance span
- `viewDurationSpan`: Tracks how long the view remains visible
- `appearCount`/`disappearCount`: Debugging counters

### Thread Safety

All components are designed for main thread usage, which is typical for SwiftUI View lifecycle events.

## Requirements

- iOS 13.0+, macOS 10.15+, tvOS 13.0+, watchOS 6.0+
- AWS OpenTelemetry Swift SDK properly initialized
- OpenTelemetry tracer provider configured

## Implementation Notes

- Uses `@State` with a reference type (`class`) to persist state across SwiftUI updates without triggering re-renders
- Only creates the main tracing spans on the first `onAppear` to avoid duplicate spans on view re-appearances
- Automatically handles span cleanup on view disappearance
- Gracefully handles cases where OpenTelemetry is not configured (minimal overhead)
