# AWSURLSessionInstrumentation

> **Note**: This instrumentation is a user of the [OpenTelemetry Swift URLSession instrumentation](https://github.com/open-telemetry/opentelemetry-swift). We extend their work with AWS-specific configuration and automatic endpoint exclusion.

## Getting Started

URLSession instrumentation is automatically enabled when network telemetry is enabled in your configuration:

```jsonc
{
  "aws": {
    "region": "us-west-2",
    "rumAppMonitorId": "your-app-monitor-id"
  },
  "applicationAttributes": {
    "application.version": "1.0.0"
  },
  "telemetry": {
    "network": { "enabled": true } // enabled by default
  }
}
```

### Manual Instrumentation

For manual initialization, you can configure URLSession through the main configuration:

```swift
import AwsOpenTelemetryCore

// Create configuration with network telemetry enabled
let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "your-app-monitor-id")
let config = AwsOpenTelemetryConfig.builder()
    .with(aws: awsConfig)
    .with(telemetry: TelemetryConfig.builder()
        .with(network: TelemetryFeature(enabled: true))
        .build())
    .build()

// Initialize the SDK
try AwsOpenTelemetryRumBuilder.create(config: config).build()
```

### Instrumentation Scope

- **Name**: `"NSURLSession"`

## Span Example

The following example shows a span generated for an S3 ListBuckets request:

```json
{
  "traceId": "64e553b8d5bf4cafe072c0c3a98d6cd4",
  "spanId": "5cf88ab002e4ee89",
  "parentSpanId": "",
  "name": "HTTP GET",
  "kind": 3,
  "startTimeUnixNano": "1756447830440854016",
  "endTimeUnixNano": "1756447830506291968",
  "attributes": [
    { "key": "http.target", "value": { "stringValue": "/" } },
    { "key": "http.method", "value": { "stringValue": "GET" } },
    {
      "key": "session.previous_id",
      "value": { "stringValue": "D368C1F0-0795-4440-A56A-4412649B490B" }
    },
    { "key": "net.peer.name", "value": { "stringValue": "s3.us-west-2.amazonaws.com" } },
    { "key": "session.id", "value": { "stringValue": "D6AA1D53-14AE-4191-83CF-0A98724324B8" } },
    { "key": "http.scheme", "value": { "stringValue": "https" } },
    { "key": "user.id", "value": { "stringValue": "05CC80ED-6202-457D-A2D7-6AB4CD6D72D8" } },
    { "key": "network.connection.type", "value": { "stringValue": "wifi" } },
    { "key": "http.status_code", "value": { "intValue": "200" } },
    {
      "key": "http.url",
      "value": { "stringValue": "https://s3.us-west-2.amazonaws.com/?x-id=ListBuckets" }
    }
  ],
  "status": {}
}
```

## Span Attributes

### Core HTTP Attributes

| Attribute                 | Type   | Description                         | Example                                                  |
| ------------------------- | ------ | ----------------------------------- | -------------------------------------------------------- |
| `http.method`             | string | HTTP request method                 | `"GET"`, `"POST"`, `"PUT"`                               |
| `http.url`                | string | Full HTTP request URL               | `"https://s3.us-west-2.amazonaws.com/?x-id=ListBuckets"` |
| `http.target`             | string | HTTP request target (path + query)  | `"/"`, `"/api/v1/users"`                                 |
| `http.scheme`             | string | HTTP scheme                         | `"https"`, `"http"`                                      |
| `http.status_code`        | int    | HTTP response status code           | `200`, `404`, `500`                                      |
| `http.request_body_size`  | int    | Size of HTTP request body in bytes  | `1024`                                                   |
| `http.response_body_size` | int    | Size of HTTP response body in bytes | `2048`                                                   |

### Network Attributes

| Attribute                 | Type   | Description                        | Example                        |
| ------------------------- | ------ | ---------------------------------- | ------------------------------ |
| `net.peer.name`           | string | Remote hostname or IP address      | `"s3.us-west-2.amazonaws.com"` |
| `net.peer.port`           | int    | Remote port number                 | `443`, `80`                    |
| `network.connection.type` | string | Network connection type (iOS only) | `"wifi"`, `"cellular"`         |

### Session Attributes (AWS Extension)

| Attribute             | Type   | Description                 | Example                                  |
| --------------------- | ------ | --------------------------- | ---------------------------------------- |
| `session.id`          | string | Current session identifier  | `"D6AA1D53-14AE-4191-83CF-0A98724324B8"` |
| `session.previous_id` | string | Previous session identifier | `"D368C1F0-0795-4440-A56A-4412649B490B"` |
| `user.id`             | string | User identifier             | `"05CC80ED-6202-457D-A2D7-6AB4CD6D72D8"` |

### AWS-Specific Exclusions

The AWS wrapper automatically excludes OTLP telemetry endpoints to prevent recursive instrumentation:

- CloudWatch RUM endpoints (`https://dataplane.rum.{region}.amazonaws.com/v1/rum`)
- Custom export override endpoints
