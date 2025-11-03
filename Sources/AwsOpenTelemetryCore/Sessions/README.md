# AwsSessionEventInstrumentation

This module is responsible for capturing the following telemetries:

1. **[Session Start](#session-start)** - Reports `session.start` events when a new session begins, following [OpenTelemetry semantic conventions](https://opentelemetry.io/docs/specs/semconv/general/session/#event-sessionstart) for session start.

2. **[Session End](#session-end)** - Reports `session.end` events when a session expires following [OpenTelemetry semantic convention](https://opentelemetry.io/docs/specs/semconv/general/session/#event-sessionend) for session end, with some extensions such as duration and end time.

## Getting Started

Session instrumentation is automatically enabled when session events telemetry is enabled in your configuration:

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
    "sessionEvents": { "enabled": true } // enabled by default
  },
  "sessionTimeout": 1800 // default 30 minutes (in seconds)
}
```

### Manual Instrumentation

For manual initialization, you can configure sessions through the main configuration:

````swift
import AwsOpenTelemetryCore

// Create configuration with session events enabled
let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "your-app-monitor-id")
let config = AwsOpenTelemetryConfig.builder()
    .with(aws: awsConfig)
    .with(sessionTimeout: 1800)
    .with(telemetry: TelemetryConfig.builder()
        .with(sessionEvents: TelemetryFeature(enabled: true))
        .build())
    .build()

## Session Configuration

The session manager can be configured by setting the `sessionTimeout` in your configuration. This determines how long a session remains active without any activity before it expires.

| Field            | Type  | Description                                                        | Default         | Required |
| ---------------- | ----- | ------------------------------------------------------------------ | --------------- | -------- |
| `sessionTimeout` | `Int` | Duration in seconds after which a session expires if left inactive | `1800` (30 min) | No       |

### Session Timeout Behavior

- Sessions automatically expire after the configured timeout period of inactivity
- Accessing a session via `getSession()` extends the expiration time

### Accessing the Session Manager

The session manager can be accessed globally using `AwsSessionManagerProvider.getInstance()`. It provides two methods for working with sessions:

```swift
let sessionManager = AwsSessionManagerProvider.getInstance()

// Get current session (extends session if active)
let session = sessionManager.getSession()

// Peek at session without extending it
if let session = sessionManager.peekSession() {
    print("Current session: \(session.id)")
}
````

### AwsSessionManager

| Method          | Return Type   | Description                                                                                                          |
| --------------- | ------------- | -------------------------------------------------------------------------------------------------------------------- |
| `getSession()`  | `AwsSession`  | Returns the current active session and extends its expiration time. If no active session exists, creates a new one.  |
| `peekSession()` | `AwsSession?` | Returns the current active session without extending its expiration time. Returns `nil` if no active session exists. |

## Session Start

A `session.start` log record is created when `getSession()` is called and the current session is expired or there is no existing session. Under the hood, AwsSessionSpanProcessor depends on `getSession()`, therefore extending or expiring the current session on every span.

### Instrumentation Scope

- **Name**: `"software.amazon.opentelemetry.Session"`

### Example Session Start Log Record

```json
{
  "body": { "string": "session.start" },
  "attributes": {
    "session.start_time": { "double": 1756431214608934000 },
    "session.id": { "string": "EA42F160-603A-43A6-8DA9-A86C88C3A275" },
    "session.previous_id": { "string": "9B98FDB4-CCAF-4529-97FC-A0078CF5F4D7" }
  },
  "instrumentationScopeInfo": { "name": "software.amazon.opentelemetry.Session" },
  "timestamp": 778124014.610989
}
```

### Session Start Attributes

| Attribute             | Type   | Description                                   | Example                                  |
| --------------------- | ------ | --------------------------------------------- | ---------------------------------------- |
| `session.id`          | string | Unique identifier for the current session     | `"EA42F160-603A-43A6-8DA9-A86C88C3A275"` |
| `session.start_time`  | double | Session start time in nanoseconds since epoch | `1756431214608934000`                    |
| `session.previous_id` | string | Identifier of the previous session (if any)   | `"9B98FDB4-CCAF-4529-97FC-A0078CF5F4D7"` |

## Session End

A `session.end` log record is created when `getSession()` is called and the previous session has expired. If a `session.end` event occurs, then a `session.start` event is also be created immediately.

### Example Session End Log Record

```json
{
  "body": { "string": "session.end" },
  "attributes": {
    "session.id": { "string": "9B98FDB4-CCAF-4529-97FC-A0078CF5F4D7" },
    "session.start_time": { "double": 1756431127415681800 },
    "session.end_time": { "double": 1756431127906623700 },
    "session.duration": { "double": 490942001 }
  },
  "instrumentationScopeInfo": { "name": "software.amazon.opentelemetry.Session" },
  "timestamp": 778124014.610947
}
```

### Session End Attributes

| Attribute            | Type   | Description                                   | Example                                  |
| -------------------- | ------ | --------------------------------------------- | ---------------------------------------- |
| `session.id`         | string | Unique identifier for the ended session       | `"9B98FDB4-CCAF-4529-97FC-A0078CF5F4D7"` |
| `session.start_time` | double | Session start time in nanoseconds since epoch | `1756431127415681800`                    |
| `session.end_time`   | double | Session end time in nanoseconds since epoch   | `1756431127906623700`                    |
| `session.duration`   | double | Session duration in nanoseconds               | `490942001` (≈490ms)                     |

## Automatic Session Attribution

The session module automatically adds session attributes to all telemetry data through dedicated processors:

### Log and Span Attribution

`AwsSessionLogRecordProcessor` automatically adds session attributes to all log records:

| Attribute             | Type   | Description                                  | Example                                  |
| --------------------- | ------ | -------------------------------------------- | ---------------------------------------- |
| `session.id`          | string | Current active session identifier            | `"EA42F160-603A-43A6-8DA9-A86C88C3A275"` |
| `session.previous_id` | string | Previous session identifier (when available) | `"9B98FDB4-CCAF-4529-97FC-A0078CF5F4D7"` |

**Special Handling**: For `session.start` and `session.end` log records, the processor preserves the existing session attributes in the log record rather than overriding them with current session data, ensuring historical accuracy of session events.

This automatic attribution ensures all telemetry data can be correlated by session without requiring manual instrumentation.
