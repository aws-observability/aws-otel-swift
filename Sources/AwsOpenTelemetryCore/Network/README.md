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

## Span Examples

### 200 HTTP Status

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

### 4xx and 5xx HTTP Status

```json
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          { "key": "telemetry.sdk.name", "value": { "stringValue": "opentelemetry" } },
          { "key": "telemetry.sdk.language", "value": { "stringValue": "swift" } },
          { "key": "service.name", "value": { "stringValue": "SimpleAwsDemo" } },
          { "key": "device.model.identifier", "value": { "stringValue": "arm64" } },
          { "key": "os.type", "value": { "stringValue": "darwin" } },
          { "key": "rum.sdk.version", "value": { "stringValue": "0.0.0" } },
          { "key": "service.version", "value": { "stringValue": "1.0 (1)" } },
          {
            "key": "os.description",
            "value": { "stringValue": "iOS Version 18.4 (Build 22E238)" }
          },
          { "key": "telemetry.sdk.version", "value": { "stringValue": "1.16.1" } },
          { "key": "awsRegion", "value": { "stringValue": "us-west-2" } },
          { "key": "os.version", "value": { "stringValue": "18.4.0" } },
          {
            "key": "awsRumAppMonitorId",
            "value": { "stringValue": "7a41f33f-d4ec-49f1-894b-b04e73118395" }
          },
          { "key": "os.name", "value": { "stringValue": "iOS" } },
          { "key": "device.id", "value": { "stringValue": "BEE3D3C8-D658-4E3F-813F-35EB083D1D2E" } }
        ]
      },
      "scopeSpans": [
        {
          "scope": { "name": "NSURLSession", "version": "0.0.1" },
          "spans": [
            {
              "traceId": "488511b3aa2e35d8e251497dea5e53c1",
              "spanId": "c2e92f83fb384f60",
              "parentSpanId": "",
              "name": "HTTP GET",
              "kind": 3,
              "startTimeUnixNano": "1756505799262493184",
              "endTimeUnixNano": "1756505799822271744",
              "attributes": [
                {
                  "key": "session.previous_id",
                  "value": { "stringValue": "C87E2CA7-4D30-4F45-A84A-65024D6FB19E" }
                },
                {
                  "key": "user.id",
                  "value": { "stringValue": "A7C03C26-09F9-4787-A5C4-F126A51D8D25" }
                },
                { "key": "http.method", "value": { "stringValue": "GET" } },
                { "key": "http.response.body.size", "value": { "intValue": "0" } },
                { "key": "network.connection.type", "value": { "stringValue": "wifi" } },
                { "key": "http.status_code", "value": { "intValue": "404" } },
                { "key": "http.scheme", "value": { "stringValue": "https" } },
                { "key": "net.peer.name", "value": { "stringValue": "httpbin.org" } },
                { "key": "http.url", "value": { "stringValue": "https://httpbin.org/status/404" } },
                {
                  "key": "session.id",
                  "value": { "stringValue": "7FA44127-48BE-438D-913A-B233C315D4F7" }
                },
                { "key": "http.target", "value": { "stringValue": "/status/404" } }
              ],
              "status": { "message": "404", "code": 2 }
            },
            {
              "traceId": "6dab79c17f941cb9566377e9533931a6",
              "spanId": "c6b47e660e97d181",
              "parentSpanId": "",
              "name": "HTTP GET",
              "kind": 3,
              "startTimeUnixNano": "1756505801616986112",
              "endTimeUnixNano": "1756505801705723904",
              "attributes": [
                { "key": "http.method", "value": { "stringValue": "GET" } },
                { "key": "net.peer.name", "value": { "stringValue": "httpbin.org" } },
                {
                  "key": "session.previous_id",
                  "value": { "stringValue": "C87E2CA7-4D30-4F45-A84A-65024D6FB19E" }
                },
                { "key": "network.connection.type", "value": { "stringValue": "wifi" } },
                { "key": "http.response.body.size", "value": { "intValue": "0" } },
                { "key": "http.url", "value": { "stringValue": "https://httpbin.org/status/500" } },
                { "key": "http.scheme", "value": { "stringValue": "https" } },
                {
                  "key": "user.id",
                  "value": { "stringValue": "A7C03C26-09F9-4787-A5C4-F126A51D8D25" }
                },
                { "key": "http.status_code", "value": { "intValue": "500" } },
                { "key": "http.target", "value": { "stringValue": "/status/500" } },
                {
                  "key": "session.id",
                  "value": { "stringValue": "7FA44127-48BE-438D-913A-B233C315D4F7" }
                }
              ],
              "status": { "message": "500", "code": 2 }
            }
          ]
        }
      ]
    }
  ]
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
