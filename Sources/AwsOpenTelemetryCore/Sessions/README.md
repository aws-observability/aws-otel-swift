# Session Instrumentation

The Session instrumentation provides automatic session tracking for OpenTelemetry Swift applications. It creates unique session identifiers, tracks session lifecycle events, and automatically adds session context to all telemetry data.

## Features

- **Automatic Session Management**: Creates and manages session lifecycles with configurable timeouts
- **Session Events**: Emits OpenTelemetry log records for session start/end events following semantic conventions
- **Span Attribution**: Automatically adds session IDs to all spans via span processor
- **Persistence**: Sessions persist across app restarts using UserDefaults
- **Thread Safety**: All components are thread-safe for concurrent access

## Quick Start

### Basic Setup

```swift
import AwsOpenTelemetryCore
import OpenTelemetrySdk

// 1. Configure session settings (optional)
let config = SessionConfiguration(sessionTimeout: 30 * 60) // 30 minutes

// 2. Create session manager
let sessionManager = SessionManager(configuration: config)

// 3. Register as singleton (optional)
SessionManagerProvider.register(sessionManager: sessionManager)

// 4. Add session span processor to tracer provider
let tracerProvider = TracerProviderBuilder()
    .add(spanProcessor: SessionSpanProcessor(sessionManager: sessionManager))
    .build()

// 5. Set up session event logging (optional)
let sessionInstrumentation = SessionEventInstrumentation()
```

### Getting Session Information

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

### SessionManager

Manages session lifecycle with automatic expiration and renewal.

```swift
let manager = SessionManager(configuration: SessionConfiguration(sessionTimeout: 1800))
let session = manager.getSession() // Creates or extends session
// or
let session = manager.peekSession() // Peeks at the current session if it exists without refreshing
```

### SessionManagerProvider

Provides thread-safe singleton access to SessionManager across your application.

```swift
// Register a custom session manager
let manager = SessionManager(configuration: SessionConfiguration(sessionTimeout: 3600))
SessionManagerProvider.register(sessionManager: manager)

// Access from anywhere in your app
let session = SessionManagerProvider.getInstance().getSession()
```

### SessionSpanProcessor

Automatically adds session IDs to all spans.

```swift
let processor = SessionSpanProcessor(sessionManager: sessionManager)
// Adds session.id and session.previous_id attributes to spans
```

### SessionEventInstrumentation

Creates OpenTelemetry log records for session lifecycle events.

```swift
let instrumentation = SessionEventInstrumentation()
// Emits session.start and session.end log records with scope "aws-otel-swift.session"
```

### Session Model

Represents a session with ID, timestamps, and expiration logic.

```swift
let session = Session(
    id: "unique-session-id",
    expireTime: Date(timeIntervalSinceNow: 1800),
    previousId: "previous-session-id"
)

print("Expired: \(session.isExpired())")
print("Duration: \(session.duration ?? 0)")
```

## Configuration

### SessionConfiguration

```swift
let config = SessionConfiguration(
    sessionTimeout: 30 * 60  // 30 minutes in seconds
)
```

### Session Timeout Behavior

- Sessions automatically expire after the configured timeout period of inactivity
- Accessing a session via `getSession()` extends the expiration time
- Expired sessions trigger session.end events and create new sessions with previous_id links

## Session Events

The instrumentation emits OpenTelemetry log records following semantic conventions:

### session.start Event

```json
{
  "body": "session.start",
  "attributes": {
    "session.id": "550e8400-e29b-41d4-a716-446655440000",
    "session.start_time": 1692123456.789,
    "session.previous_id": "previous-session-id" // if applicable
  }
}
```

### session.end Event

```json
{
  "body": "session.end",
  "attributes": {
    "session.id": "550e8400-e29b-41d4-a716-446655440000",
    "session.start_time": 1692123456.789,
    "session.end_time": 1692125256.789,
    "session.duration": 1800.0,
    "session.previous_id": "previous-session-id" // if applicable
  }
}
```

## Persistence

Sessions are automatically persisted to UserDefaults and restored on app restart:

- Active sessions continue from their previous state
- Expired sessions create new sessions with proper previous_id linking
- Session data is saved periodically (every 30 seconds) to minimize disk I/O

## Thread Safety

All components are designed for concurrent access:

- `SessionManager` uses locks for thread-safe session access
- `SessionManagerProvider` provides thread-safe singleton access
- `SessionStore` handles concurrent persistence operations safely

## Best Practices

1. **Use SessionManagerProvider**: Register your session manager as a singleton for consistent access across your app
2. **Configure Appropriate Timeouts**: Set session timeouts based on your app's usage patterns (default: 30 minutes)
3. **Add Span Processor Early**: Register the SessionSpanProcessor before creating spans to ensure all telemetry includes session context
4. **Handle Session Events**: Set up SessionEventInstrumentation to capture session lifecycle for analytics

## Example: Complete Integration

```swift
import OpenTelemetrySdk
import AwsOpenTelemetryCore

class TelemetrySetup {
    static func configure() {
        // 1. Configure session management
        let sessionConfig = SessionConfiguration(sessionTimeout: 45 * 60) // 45 minutes
        let sessionManager = SessionManager(configuration: sessionConfig)
        SessionManagerProvider.register(sessionManager: sessionManager)

        // 2. Set up tracer with session processor
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: SessionSpanProcessor(sessionManager: sessionManager))
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: ConsoleSpanExporter()))
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        // 3. Set up session event logging
        let loggerProvider = LoggerProviderBuilder()
            .with(processors: [SimpleLogRecordProcessor(logRecordExporter: ConsoleLogRecordExporter())])
            .build()
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
        let sessionInstrumentation = SessionEventInstrumentation()
    }
}
```
