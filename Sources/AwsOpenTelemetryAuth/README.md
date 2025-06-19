# AWS OpenTelemetry Auth Module

The `AwsOpenTelemetryAuth` module provides AWS authentication capabilities for OpenTelemetry exporters, enabling secure communication with AWS services using AWS Signature Version 4 (SigV4) authentication.

## Overview

This module extends the core OpenTelemetry functionality by adding AWS-specific authentication mechanisms. It includes:

- **AWS SigV4 Authentication**: Sign HTTP requests with AWS SigV4 signatures
- **Cognito Credentials Provider**: Manage AWS credentials using Amazon Cognito Identity
- **Authenticated Exporters**: Span and log exporters with built-in AWS authentication
- **Request Interceptors**: Middleware for adding authentication to HTTP requests

## Components

### Core Authentication

#### `AwsSigV4Authenticator`
A utility class that provides AWS Signature Version 4 authentication functionality. It signs HTTP requests with AWS SigV4 signatures to authenticate requests to AWS services.

#### `CognitoCachedCredentialsProvider`
A credentials provider that uses Amazon Cognito Identity to obtain and cache AWS credentials. It automatically refreshes credentials when they expire and provides a configurable refresh buffer window.

**Key Features:**
- Automatic credential caching and refresh
- Configurable refresh buffer window (default: 10 seconds)
- Support for authenticated and unauthenticated identities
- Integration with Cognito Identity Pools

#### `AwsSigV4RequestInterceptor`
An HTTP request interceptor that automatically adds AWS SigV4 authentication headers to outgoing requests.

### Exporters

#### `AwsSigV4SpanExporter`
A span exporter that adds AWS SigV4 authentication to span export requests. It wraps an OTLP HTTP exporter and ensures that all outgoing requests are signed with AWS SigV4 authentication.

#### `AwsSigV4LogRecordExporter`
A log record exporter that adds AWS SigV4 authentication to log export requests, similar to the span exporter but for log data.

#### Builder Classes
- `AwsSigV4SpanExporterBuilder`: Builder pattern for creating authenticated span exporters
- `AwsSigV4LogRecordExporterBuilder`: Builder pattern for creating authenticated log exporters

### Error Handling

#### `AwsOpenTelemetryAuthError`
Defines specific error types that can occur during authentication:
- `noIdentityId`: When unable to obtain a Cognito identity ID
- `credentialsError`: When credential retrieval or processing fails

## Usage

### Basic Setup with Cognito

```swift
import AwsOpenTelemetryAuth
import AWSCognitoIdentity

// Create a Cognito Identity client
let cognitoClient = try CognitoIdentityClient(region: "us-west-2")

// Create a credentials provider
let credentialsProvider = CognitoCachedCredentialsProvider(
    cognitoPoolId: "us-west-2:your-identity-pool-id",
    cognitoClient: cognitoClient
)

// Create an authenticated span exporter
let spanExporter = try AwsSigV4SpanExporterBuilder()
    .setEndpoint("https://your-otel-endpoint.amazonaws.com")
    .setRegion("us-west-2")
    .setServiceName("xray")
    .setCredentialsProvider(credentialsProvider)
    .build()
```

### Using with Custom Credentials

```swift
// Create your own credentials provider
let customCredentialsProvider = YourCustomCredentialsProvider()

// Create authenticated exporters
let spanExporter = try AwsSigV4SpanExporterBuilder()
    .setEndpoint("https://your-endpoint.amazonaws.com")
    .setRegion("us-east-1")
    .setServiceName("xray")
    .setCredentialsProvider(customCredentialsProvider)
    .build()

let logExporter = try AwsSigV4LogRecordExporterBuilder()
    .setEndpoint("https://your-logs-endpoint.amazonaws.com")
    .setRegion("us-east-1")
    .setServiceName("logs")
    .setCredentialsProvider(customCredentialsProvider)
    .build()
```

### Integration with Core SDK

```swift
import AwsOpenTelemetryCore
import AwsOpenTelemetryAuth

// Create authenticated exporters
let authenticatedSpanExporter = try AwsSigV4SpanExporterBuilder()
    .setEndpoint("https://your-endpoint.amazonaws.com")
    .setRegion("us-west-2")
    .setServiceName("xray")
    .setCredentialsProvider(credentialsProvider)
    .build()

// Use with the core SDK builder
let config = AwsOpenTelemetryConfig(
    rum: RumConfig(region: "us-west-2", appMonitorId: "your-app-monitor-id"),
    application: ApplicationConfig(applicationVersion: "1.0.0")
)

try AwsOpenTelemetryRumBuilder.create(config: config)
    .addSpanExporterCustomizer { _ in
        return authenticatedSpanExporter
    }
    .build()
```

## Dependencies

This module depends on:
- `AwsOpenTelemetryCore`: Core OpenTelemetry functionality
- `AwsCommonRuntimeKit`: AWS common runtime utilities
- `AWSCognitoIdentity`: Amazon Cognito Identity service client
- `AWSSDKHTTPAuth`: AWS SDK HTTP authentication
- `SmithyHTTPAuth`: Smithy HTTP authentication framework
- OpenTelemetry SDK components for exporters

## Security Considerations

- Credentials are cached securely and automatically refreshed
- All HTTP requests are signed with AWS SigV4 for authentication
- The module follows AWS security best practices for credential management
- Credentials are never logged or exposed in error messages

## Thread Safety

All components in this module are designed to be thread-safe:
- `CognitoCachedCredentialsProvider` uses internal synchronization for credential caching
- Exporters can be safely used from multiple threads
- Authentication operations are atomic and thread-safe

## Error Handling

The module provides specific error types for different failure scenarios:
- Authentication failures are clearly distinguished from network errors
- Credential refresh failures are handled gracefully with appropriate fallbacks
- All errors include descriptive information for debugging

## Performance

- Credentials are cached to minimize authentication overhead
- SigV4 signing is performed efficiently with minimal memory allocation
- Exporters reuse underlying HTTP connections when possible
- Configurable refresh buffer prevents unnecessary credential refreshes
