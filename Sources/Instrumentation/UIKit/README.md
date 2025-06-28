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
- **Comprehensive Lifecycle Tracking** - Monitors all major view controller lifecycle events
- **Custom Naming Support** - Override default class names for better observability
- **Selective Opt-Out** - Disable instrumentation for specific view controllers
- **Thread-Safe Operations** - Handles concurrent view controller operations safely
- **Background State Handling** - Properly manages spans during app backgrounding
- **Bundle Filtering** - Only instruments your app's view controllers, not system ones

## Automatic Setup

View instrumentation is **enabled by default** when you initialize the AWS OpenTelemetry SDK:

```swift
let config = AwsOpenTelemetryConfig(
  rum: RumConfig(region: "us-west-2", appMonitorId: "your-app-monitor-id"),
  application: ApplicationConfig(applicationVersion: "1.0.0")
  // telemetry.isUiKitViewInstrumentationEnabled defaults to true
)

try AwsOpenTelemetryRumBuilder.create(config: config).build()
```

## Configuration Options

### Disable UIKit Instrumentation

```swift
let config = AwsOpenTelemetryConfig(
  rum: RumConfig(region: "us-west-2", appMonitorId: "your-app-monitor-id"),
  application: ApplicationConfig(applicationVersion: "1.0.0"),
  telemetry: TelemetryConfig(isUiKitViewInstrumentationEnabled: false)
)
```

### JSON Configuration

You can also configure instrumentation via `aws_config.json`:

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
    "isUiKitViewInstrumentationEnabled": true
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
├── viewIsAppearing (Child Span - iOS 13+)
└── viewDidAppear (Child Span)

view.duration (Root Span - measures visibility time)
└── (Duration from viewDidAppear to viewDidDisappear)
```

### Span Attributes

Each span includes contextual information:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `view.name` | Display name for the view | "Login Screen" or "LoginViewController" |
| `view.class` | Actual class name | "LoginViewController" |

## Platform Support

- **iOS 13.0+**: Full support including `viewIsAppearing`
- **iOS 12.0+**: Support without `viewIsAppearing` method
- **tvOS**: Full support for all lifecycle methods
- **Mac Catalyst**: Full support for all lifecycle methods
- **watchOS**: Not supported (UIKit not available)

## Implementation Details

### Safety and Reliability

The instrumentation prioritizes application stability and performance:

#### Safety Features
- **Bundle Filtering**: Only instruments your app's view controllers, never system ones
- **State Tracking**: Prevents duplicate instrumentation attempts
- **Error Isolation**: Comprehensive error handling prevents crashes
- **Graceful Degradation**: App continues normally even if instrumentation fails
- **Original Method Preservation**: Always calls original methods before adding instrumentation

#### Thread Safety
- **Serial Queue**: All span operations use a dedicated serial queue
- **Thread-Safe Storage**: Span dictionaries use `@ThreadSafe` property wrapper
- **Main Thread Lifecycle**: Respects UIKit's main thread requirements

#### Memory Management
- **Automatic Cleanup**: Spans are automatically cleaned up when view controllers are deallocated
- **Background Handling**: Properly handles app backgrounding to prevent memory leaks
- **Weak References**: Uses weak references to prevent retain cycles

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

## Troubleshooting

### Common Issues

1. **No spans appearing**: Ensure UIKit instrumentation is enabled in your configuration
2. **System view controllers being instrumented**: Check bundle filtering is working correctly
3. **Memory issues**: Verify proper cleanup in background/foreground transitions

### Debug Logging

Enable debug logging to troubleshoot instrumentation issues:

```swift
let config = AwsOpenTelemetryConfig(
  rum: RumConfig(
    region: "us-west-2", 
    appMonitorId: "your-app-monitor-id",
    debug: true  // Enable debug logging
  ),
  application: ApplicationConfig(applicationVersion: "1.0.0")
)
```

## Best Practices

1. **Use Custom Names**: Provide meaningful names for better observability
2. **Selective Opt-Out**: Only disable instrumentation when necessary
3. **Monitor Performance**: Watch for any performance impact in your app
4. **Test Thoroughly**: Verify instrumentation works correctly with your view controller patterns

## Requirements

- iOS 13.0+ (iOS 12.0+ with limited functionality)
- UIKit framework
- AWS OpenTelemetry Swift SDK
- OpenTelemetry Swift SDK dependencies
