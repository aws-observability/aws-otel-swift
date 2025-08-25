# Session Instrumentation

Automatic session tracking for OpenTelemetry Swift applications. Creates unique session identifiers, tracks session lifecycle events, and automatically adds session context to all telemetry data.

## Features

- **Automatic Session Management** - Creates and manages session lifecycles with configurable timeouts
- **Session Events** - Emits OpenTelemetry log records for session start/end events
- **Span Attribution** - Automatically adds session IDs to all spans via span processor
- **Persistence** - Sessions persist across app restarts using UserDefaults
- **Thread Safety** - All components are thread-safe for concurrent access

## Setup

**Basic Setup** (default 30-minute timeout):

```swift
import AwsOpenTelemetryCore
import OpenTelemetrySdk

let sessionInstrumentation = AwsSessionEventInstrumentation()
let sessionSpanProcessor = AwsSessionSpanProcessor()

let tracerProvider = TracerProviderBuilder()
    .add(spanProcessor: sessionSpanProcessor)
    .build()
```

**Custom Configuration**:

```swift
let sessionConfig = AwsSessionConfig.builder()
  .with(sessionTimeout: 45 * 60)
  .build()

let sessionManager = AwsSessionManager(configuration: sessionConfig)
AwsSessionManagerProvider.register(sessionManager: sessionManager)
```

**Getting Session Information**:

```swift
// Get current session (extends session if active)
let session = sessionManager.getSession()
print("Session ID: \(session.id)")

// Peek at session without extending it
if let session = sessionManager.peekSession() {
    print("Current session: \(session.id)")
}
```

## Components

### AwsSessionManager

Manages session lifecycle with automatic expiration and renewal.

```swift
// Direct initialization
let manager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: 1800))

// Using builder pattern
let config = AwsSessionConfig.builder()
  .with(sessionTimeout: 1800)
  .build()
let manager = AwsSessionManager(configuration: config)

let session = manager.getSession() // Creates or extends session
let session = manager.peekSession() // Peek without extending
```

### AwsSessionManagerProvider

Provides thread-safe singleton access to AwsSessionManager.

```swift
// Register a custom session manager
let config = AwsSessionConfig.builder()
  .with(sessionTimeout: 3600)
  .build()
let manager = AwsSessionManager(configuration: config)
AwsSessionManagerProvider.register(sessionManager: manager)

// Access from anywhere in your app
let session = AwsSessionManagerProvider.getInstance().getSession()
```

### AwsSessionSpanProcessor

Automatically adds session IDs to all spans.

```swift
let processor = AwsSessionSpanProcessor(sessionManager: sessionManager)
// Adds session.id and session.previous_id attributes to spans
```

### AwsSessionEventInstrumentation

Creates OpenTelemetry log records for session lifecycle events.

```swift
let instrumentation = AwsSessionEventInstrumentation()
// Emits session.start and session.end log records
```

### AwsSession Model

Represents a session with ID, timestamps, and expiration logic.

```swift
let session = AwsSession(
    id: "unique-session-id",
    expireTime: Date(timeIntervalSinceNow: 1800),
    previousId: "previous-session-id"
)

print("Expired: \(session.isExpired)")
print("Duration: \(session.duration ?? 0)")
```

## Configuration

### AwsSessionConfig

| Field            | Type  | Description                                                        | Default         | Required |
| ---------------- | ----- | ------------------------------------------------------------------ | --------------- | -------- |
| `sessionTimeout` | `Int` | Duration in seconds after which a session expires if left inactive | `1800` (30 min) | No       |

### Session Timeout Behavior

- Sessions automatically expire after the configured timeout period of inactivity
- Accessing a session via `getSession()` extends the expiration time
- Expired sessions trigger `session.end` events and create new sessions with `previous_id` links

## Session Events

Emits OpenTelemetry log records following semantic conventions:

**session.start Event**:

```json
{
  "body": "session.start",
  "attributes": {
    "session.id": "550e8400-e29b-41d4-a716-446655440000",
    "session.start_time": 1692123456.789,
    "session.previous_id": "previous-session-id"
  }
}
```

**session.end Event**:

```json
{
  "body": "session.end",
  "attributes": {
    "session.id": "550e8400-e29b-41d4-a716-446655440000",
    "session.start_time": 1692123456.789,
    "session.end_time": 1692125256.789,
    "session.duration": 1800.0,
    "session.previous_id": "previous-session-id"
  }
}
```

## Persistence

Sessions are automatically persisted to UserDefaults and restored on app restart:

- Active sessions continue from their previous state
- Expired sessions create new sessions with proper `previous_id` linking
- Session data is saved periodically (every 30 seconds) to minimize disk I/O

## Thread Safety

All components are designed for concurrent access:

- `AwsSessionManager` uses locks for thread-safe session access
- `AwsSessionStore` handles concurrent persistence operations safely

## Best Practices

1. **Use AwsSessionManagerProvider** - Register your session manager as a singleton for consistent access across your app
2. **Configure Appropriate Timeouts** - Set session timeouts based on your app's usage patterns
3. **Add Span Processor Early** - Register the AwsSessionSpanProcessor before creating spans
4. **Handle Session Events** - Set up AwsSessionEventInstrumentation to capture session lifecycle
