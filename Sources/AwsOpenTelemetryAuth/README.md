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

### Using CognitoCachedCredentialsProvider with loginsMap

The `loginsMap` parameter allows you to provide tokens from federated identity providers such as Amazon, Facebook, Google, or any OpenID Connect-compatible provider.

```swift
import AwsOpenTelemetryAuth

// Example with Amazon Login
let amazonLoginsMap = [
    "www.amazon.com": "amazon-access-token-here"
]

let amazonCredentialsProvider = CognitoCachedCredentialsProvider(
    identityPoolId: "us-west-2:your-identity-pool-id",
    region: "us-west-2",
    loginsMap: amazonLoginsMap
)

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
