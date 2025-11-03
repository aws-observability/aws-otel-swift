# App Launch Instrumentation

The App Launch instrumentation module provides automatic tracking of iOS application launch performance by creating OpenTelemetry spans that measure cold and warm launch times, including pre-warm launch detection.

## Overview

This instrumentation captures different types of app launches:

- **Cold Launch**: App starts from scratch (process creation to launch completion)
- **Warm Launch**: App returns from background to foreground
- **Pre-warm Launch**: A cold launch that was pre-warmed by the OS, either explicitly with the active-prewarm flag or implicitly if app launch time exceeds a threshold (default 30 seconds)

## Components

### AppLaunchProvider

A protocol that defines the interface for providing app launch timing data:

```swift
public protocol AppLaunchProvider {
  var coldLaunchStartTime: Date { get }
  var coldEndNotification: Notification.Name { get }
  var warmStartNotification: Notification.Name { get }
  var warmEndNotification: Notification.Name { get }
  var preWarmFallbackThreshold: TimeInterval { get }
}
```

#### AppLaunchProvider Parameters

| Parameter                  | Type                | Description                                                                                                                            | Default (DefaultAppLaunchProvider)              |
| -------------------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `coldLaunchStartTime`      | `Date`              | The time when the app process started                                                                                                  | Process start time from `kinfo_proc`            |
| `warmStartNotification`    | `Notification.Name` | Notification fired when warm launch begins                                                                                             | `UIApplication.willEnterForegroundNotification` |
| `launchEnd`                | `Notification.Name` | Notification fired when a launch completes                                                                                             | `UIApplication.didBecomeActiveNotification`     |
| `preWarmFallbackThreshold` | `TimeInterval`      | Duration threshold (seconds) above which launches are classified as pre-warm. Set to `0` to disable threshold-based fallback detection | `30.0`                                          |

### DefaultAppLaunchProvider

The default implementation that:

- Calculates process start time using `kinfo_proc` system call for accurate cold launch timing
- Uses `UIApplication.willEnterForegroundNotification` for warm launch start
- Uses `UIApplication.didBecomeActiveNotification` for all launch completions
- Sets pre-warm threshold to 30 seconds by default
- Only available on UIKit platforms (iOS, tvOS, macOS with UIKit)

### AwsAppLaunchInstrumentation

The main instrumentation class that:

- Creates `AppStart` spans for both cold and warm launches
- Detects pre-warm launches using duration thresholds or `ActivePrewarm` environment variable
- Ensures only one cold launch is recorded per app session
- Tracks warm launch start times automatically after the first hidden event fires
- Uses thread-safe static state management

## Launch Type Detection

### Cold Launch

- Triggered by the first `launchEndNotification`
- Measures from process start to launch completion
- Automatically classified as `PRE_WARM` if duration exceeds threshold or `ActivePrewarm` flag was detected

### Warm Launch

- Only recorded after a hidden event fires to avoid writing warm launch for the initial launch
- Triggered by `warmStartNotification` and `launchEndNotification`
- Measures from foreground entry to active state

### Pre-warm Detection

- Uses `ActivePrewarm` environment variable if present
- Falls back to duration-based detection using `preWarmFallbackThreshold`
- Threshold of 0 disables fallback detection

## Usage

The instrumentation is automatically enabled when the `startup` telemetry feature is enabled:

```json
{
  "telemetry": {
    "startup": { "enabled": true }
  }
}
```

Or programmatically:

```swift
let config = AwsTelemetryConfig()
  .withStartup(enabled: true)
```

## Custom Implementation

You can provide a custom provider:

```swift
let customProvider = MyAppLaunchProvider()
let instrumentation = AwsAppLaunchInstrumentation(provider: customProvider)
```

## Platform Behavior

- **iOS/tvOS/macOS with UIKit**: Full functionality with default notifications
- **watchOS or non-UIKit platforms**: Requires custom provider implementation

## Generated Telemetry

The instrumentation creates spans with:

- **Name**: `AppStart`
- **Attributes**:
  - `launch.type`: `COLD`, `WARM`, or `PRE_WARM`
  - `launch_start_name`: Name of the start notification
  - `launch_end_name`: Name of the end notification
  - `active_prewarm`: Boolean indicating if `ActivePrewarm` environment variable is set
- **Instrumentation Scope**: `software.amazon.opentelemetry.AppStart`
- **Timing**: Accurate start/end times based on actual system events
