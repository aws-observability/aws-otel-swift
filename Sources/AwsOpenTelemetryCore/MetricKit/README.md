# AwsMetricKitSubscriber

This module is responsible for capturing the following telemetries:

1. **[Crashes](#crashes)** - Reports Apple [MXCrashDiagnostic](https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic) as soon as it is available. Currently, only iOS 15+ is supported where MXCrashDiagnostic is reported immediately.

2. **[Hangs](#hangs)** - Reports Apple [MXHangDiagnostic](https://developer.apple.com/documentation/metrickit/mxhangdiagnostic?language=objc) as soon as it is available. Currently, only iOS 15+ is supported where MXHangDiagnostic is reported immediately.

## Getting Started

MetricKit instrumentation is automatically enabled when crash and hang telemetry are enabled in your configuration:

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
    "crash": { "enabled": true }, // enabled by default
    "hang": { "enabled": true } // enabled by default
  }
}
```

### Manual Instrumentation

For manual initialization, you can configure MetricKit through the main configuration:

```swift
import AwsOpenTelemetryCore

// Create configuration with MetricKit enabled
let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "your-app-monitor-id")
let config = AwsOpenTelemetryConfig.builder()
    .with(aws: awsConfig)
    .with(telemetry: TelemetryConfig.builder()
        .with(crash: TelemetryFeature(enabled: true))
        .with(hang: TelemetryFeature(enabled: true))
        .build())
    .build()

// Initialize the SDK
try AwsOpenTelemetryRumBuilder.create(config: config).build()
```

## Crashes

### Instrumentation Scope

- **Name**: `"software.amazon.opentelemetry.MXCrashDiagnostic"`

### Example Crash Log Record

```json
{
  "body": { "string": "crash" },
  "attributes": {
    "crash.exception_type": { "int": 1 },
    "crash.exception_code": { "int": 2 },
    "crash.signal": { "int": 11 },
    "crash.termination_reason": { "string": "Namespace SIGNAL, Code 0xb" },
    "crash.exception_reason.type": { "string": "NSException" },
    "crash.exception_reason.name": { "string": "NSInvalidArgumentException" },
    "crash.exception_reason.message": {
      "string": "*** -[__NSArrayM objectAtIndex:]: index 10 beyond bounds [0 .. 2]"
    },
    "crash.exception_reason.class_name": { "string": "NSException" },
    "crash.vm_region.info": {
      "string": "MALLOC_NANO (reserved) 280000000000-2c0000000000 [256.0G] rw-/rwx SM=NUL  reserved VM address space (unallocated)"
    },
    "crash.stacktrace": {
      "string": "{\"callStacks\":[{\"threadAttributed\":true,\"callStackRootFrames\":[{\"binaryUUID\":\"0102E659-3745-41D7-95D5-1757A41FFA60\",\"offsetIntoBinaryTextSegment\":123,\"sampleCount\":1,\"binaryName\":\"MyApp\",\"address\":74565}]}],\"callStackPerThread\":true}"
    }
  },
  "instrumentationScopeInfo": { "name": "software.amazon.opentelemetry.MXCrashDiagnostic" },
  "timestamp": 778123933.802745
}
```

### MXCrashDiagnostic Attributes

| Attribute                           | Type   | Description                               | Example                                                               |
| ----------------------------------- | ------ | ----------------------------------------- | --------------------------------------------------------------------- |
| `crash.exception_type`              | int    | Exception type from MXCrashDiagnostic     | `1`                                                                   |
| `crash.exception_code`              | int    | Exception code from MXCrashDiagnostic     | `2`                                                                   |
| `crash.signal`                      | int    | Signal number that caused the crash       | `11` (SIGSEGV)                                                        |
| `crash.termination_reason`          | string | Termination reason from MXCrashDiagnostic | `"Namespace SIGNAL, Code 0xb"`                                        |
| `crash.exception_reason.type`       | string | Exception type (iOS 17+)                  | `"NSException"`                                                       |
| `crash.exception_reason.name`       | string | Exception name (iOS 17+)                  | `"NSInvalidArgumentException"`                                        |
| `crash.exception_reason.message`    | string | Exception message (iOS 17+)               | `"*** -[__NSArrayM objectAtIndex:]: index 10 beyond bounds [0 .. 2]"` |
| `crash.exception_reason.class_name` | string | Exception class name (iOS 17+)            | `"NSException"`                                                       |
| `crash.vm_region.info`              | string | Virtual memory region information         | `"MALLOC_NANO (reserved) 280000000000-2c0000000000..."`               |
| `crash.stacktrace`                  | string | JSON representation of call stack tree    | `"{\"callStacks\":[...],\"callStackPerThread\":true}"`                |

## Hangs

### Instrumentation Scope

- **Name**: `"software.amazon.opentelemetry.MXHangDiagnostic"`

### Example Hang Log Record

```json
{
  "body": { "string": "hang" },
  "attributes": {
    "hang.hang_duration": { "double": 20000000000 },
    "hang.stacktrace": {
      "string": "{\n  \"callStacks\" : [\n    {\n      \"threadAttributed\" : true,\n      \"callStackRootFrames\" : [\n        {\n          \"binaryUUID\" : \"0102E659-3745-41D7-95D5-1757A41FFA60\",\n          \"offsetIntoBinaryTextSegment\" : 123,\n          \"sampleCount\" : 20,\n          \"binaryName\" : \"testBinaryName\",\n          \"address\" : 74565\n        }\n      ]\n    }\n  ],\n  \"callStackPerThread\" : true\n}"
    }
  },
  "instrumentationScopeInfo": { "name": "software.amazon.opentelemetry.MXHangDiagnostic" },
  "timestamp": 778123933.802745
}
```

### MXHangDiagnostic Attributes

| Attribute            | Type   | Description                                        | Example                                                |
| -------------------- | ------ | -------------------------------------------------- | ------------------------------------------------------ |
| `hang.hang_duration` | double | Duration of the hang in nanoseconds                | `20000000000` (20 seconds)                             |
| `hang.stacktrace`    | string | JSON representation of call stack tree during hang | `"{\"callStacks\":[...],\"callStackPerThread\":true}"` |
