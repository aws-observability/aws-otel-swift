# User Identification (UID) Module

This module is responsible for managing and adding unique user identifiers to telemetry data:

1. **[UID Management](#uid-management)** - Generates and persists unique user identifiers across app sessions
2. **[Log and Span Attribution](#log-and-span-attribution)** - Automatically adds UID attributes to all spans

## Getting Started

UID instrumentation is automatically enabled when the AWS OpenTelemetry SDK is initialized. No additional configuration is required.

```swift
import AwsOpenTelemetryCore

// UID tracking is automatically enabled
let config = AwsOpenTelemetryConfig(
    aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "your-app-monitor-id"),
    applicationAttributes: ["application.version": "1.0.0"]
)

try AwsOpenTelemetryRumBuilder.create(config: config).build()
```

## UID Management

The `AwsUIDManager` automatically generates a unique identifier when first accessed and persists it to `UserDefaults` for consistency across app sessions.

### Accessing the UID Manager

The UID manager can be accessed globally at runtime using `AwsUIDManagerProvider.getInstance()`:

```swift
let uidManager = AwsUIDManagerProvider.getInstance()
let currentUID = uidManager.getUID()
```

### AwsUIDManager

| Method     | Return Type | Description                                                               |
| ---------- | ----------- | ------------------------------------------------------------------------- |
| `getUID()` | `String`    | Returns the current unique user identifier, generating one if none exists |

### UID Persistence

- UIDs are automatically persisted to `UserDefaults` with key `"aws-rum-user-id"`
- The same UID is maintained for the lifespan of the device or until the entry in `UserDefaults` is overriden.
- Thread-safe access is guaranteed through internal locking

## Log and Span Attribution

- `AwsUIDSpanProcessor` automatically adds the current UID to all spans as they are created.
- `AwsUIDLogRecordProcessor` automatically adds the current UID to all log records before they are exported.

### Attributes

| Attribute | Type   | Description                    | Example                                  |
| --------- | ------ | ------------------------------ | ---------------------------------------- |
| `user.id` | string | Unique identifier for the user | `"550E8400-E29B-41D4-A716-446655440000"` |

### Example Enhanced Log Record

```jsonc
{
  "timeUnixNano": "1756706053966820096",
  "body": { "stringValue": "session.start" },
  "attributes": [
    {
      "key": "session.previous_id",
      "value": { "stringValue": "C5E0551F-5088-4E8D-AFB6-1B946925954A" }
    },
    { "key": "session.start_time", "value": { "doubleValue": 1756706053960432000 } },
    {
      "key": "session.id",
      "value": { "stringValue": "72FF838F-E546-4C47-950E-E3FDA5C05BD3" }
    },
    {
      "key": "user.id", // here
      "value": { "stringValue": "1CBF1932-6111-4C87-89A3-8CD7B971187B" }
    }
  ]
}
```

## Architecture

The UID module follows a provider pattern for consistent access:

- **AwsUIDManager**: Core UID generation and persistence logic
- **AwsUIDManagerProvider**: Thread-safe singleton access to UID manager
- **AwsUIDSpanProcessor**: Adds UID attributes to spans during creation
- **AwsUIDLogRecordProcessor**: Adds UID attributes to log records before export

All components are automatically integrated into the OpenTelemetry pipeline when the SDK is initialized.
