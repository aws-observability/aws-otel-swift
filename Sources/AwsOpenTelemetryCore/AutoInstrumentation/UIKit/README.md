# UIKit View Instrumentation

Automatic performance monitoring for UIKit view controllers using OpenTelemetry.

## Overview

This module automatically instruments UIViewController lifecycle methods to collect performance telemetry without requiring any code changes to your view controllers. It provides comprehensive insights into view loading performance and user engagement patterns.

## Key Metrics Collected

- **View Load Performance**: Complete lifecycle from `viewDidLoad` → `viewDidAppear`
- **View Visibility Duration**: Time from `viewDidAppear` → `viewDidDisappear`
- **Individual Lifecycle Events**: Detailed timing for each lifecycle method
- **User Navigation Patterns**: Understanding of screen transitions and usage

## Features

- **Zero-Code Integration** - Automatic instrumentation with no code changes required
- **Comprehensive Lifecycle Tracking** - Monitors the following view controller lifecycle events: `viewDidLoad`, `viewWillAppear`, `viewIsAppearing`, `viewDidAppear`, `viewDidDisappear`
- **Custom Naming Support** - Override default class names for better observability
- **Selective Opt-Out** - Disable instrumentation for specific view controllers
- **Bundle Filtering** - Only instruments your app's view controllers, not system ones

## Automatic Setup

View instrumentation is **enabled by default** when you initialize the AWS OpenTelemetry SDK. Refer below to disable this instrumenation.

## Configuration Options

### Disable UIKit Instrumentation

```swift
let config = AwsOpenTelemetryConfig(
  rum: RumConfig(region: "your-region", appMonitorId: "your-app-monitor-id"),
  application: ApplicationConfig(applicationVersion: "1.0.0"),
  telemetry: TelemetryConfig(isUiKitViewInstrumentationEnabled: false)
)
```

### JSON Configuration

You can also disable instrumentation via `aws_config.json`:

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
    "isUiKitViewInstrumentationEnabled": false
  }
}
```

## Customization

### Custom View Names

Provide user-friendly names for better observability:

```swift
class LoginViewController: UIViewController, ViewControllerCustomization {
  var customViewName: String? { "Login Screen" }
  var shouldCaptureView: Bool { true }
}
```

### Opt-Out of Instrumentation

Disable instrumentation for specific view controllers:

```swift
class DebugViewController: UIViewController, ViewControllerCustomization {
  var shouldCaptureView: Bool { false } // Skip instrumentation
}
```

## Generated Telemetry

### Span Hierarchy

```
view.load (Root Span - measures complete loading time)
├── viewDidLoad (Child Span)
├── viewWillAppear (Child Span)
├── viewIsAppearing (Child Span)
└── viewDidAppear (Child Span)

view.duration (Root Span - measures view duration time, from viewDidAppear to viewDidDisappear)
```

### Span Attributes

Each span includes contextual information:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `view.name` | Display name for the view | "Login Screen" or "LoginViewController" |
| `view.class` | Actual class name | "LoginViewController" |

## Implementation Details

### Method Swizzling

The instrumentation uses runtime method swizzling to intercept lifecycle methods:

```swift
// Example of safe method swizzling
guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
      let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
  print("[UIKitViewInstrumentation] Error: Could not find methods for swizzling")
  return // App continues normally
}

method_exchangeImplementations(originalMethod, swizzledMethod)
```

## Best Practices

1. **Use Custom Names**: Provide meaningful names for better observability
2. **Selective Opt-Out**: Only disable instrumentation when necessary
3. **Monitor Performance**: Watch for any performance impact in your app
4. **Test Thoroughly**: Verify instrumentation works correctly with your view controller patterns
