# AWS OpenTelemetry Auth Module

The `AwsOpenTelemetryAuth` module provides AWS authentication capabilities for OpenTelemetry exporters, enabling secure communication with AWS services.

## Getting Started

### Basic Setup with Cognito

```swift
import AwsOpenTelemetryAuth
import AWSCognitoIdentity

let region = "your-region"

// Create a Cognito Identity client
let cognitoClient = try CognitoIdentityClient(region: region)

// Create a credentials provider
let credentialsProvider = CognitoCachedCredentialsProvider(
    cognitoPoolId: "\(region):your-identity-pool-id",
    cognitoClient: cognitoClient
)

// Create an authenticated span exporter (uses default AWS RUM endpoint)
let spanExporter = try AwsSigV4SpanExporter.builder()
    .setRegion(region: region)
    .setCredentialsProvider(credentialsProvider: credentialsProvider)
    .build()
```

### Using CognitoCachedCredentialsProvider with loginsMap

The `loginsMap` parameter allows you to provide tokens from federated identity providers such as Amazon, Facebook, Google, or any OpenID Connect-compatible provider.

```swift
// Example with Amazon Login
let amazonLoginsMap = [
    "www.amazon.com": "amazon-access-token-here"
]

let credentialsProvider = CognitoCachedCredentialsProvider(
    cognitoPoolId: "\(region):your-identity-pool-id",
    cognitoClient: cognitoClient,
    loginsMap: amazonLoginsMap
)
```

### Complete Integration Example

Here's a complete example showing how to integrate AWS SigV4 authentication with the AWS OpenTelemetry SDK:

```swift
import AwsOpenTelemetryCore
import AwsOpenTelemetryAuth
import AWSCognitoIdentity

class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    setupOpenTelemetry()
    return true
  }

  private func setupOpenTelemetry() {
    Task {
      do {
        let region = "us-east-1"
        let cognitoIdentityPoolId = "\(region):your-identity-pool-id"

        // Create Cognito credentials provider
        let cognitoClient = try CognitoIdentityClient(region: region)
        let credentialsProvider = CognitoCachedCredentialsProvider(
          cognitoPoolId: cognitoIdentityPoolId,
          cognitoClient: cognitoClient
        )

        // Create SigV4 exporters (uses default AWS RUM endpoints)
        let sigv4SpanExporter = try AwsSigV4SpanExporter.builder()
          .setRegion(region: region)
          .setServiceName(serviceName: "rum")
          .setCredentialsProvider(credentialsProvider: credentialsProvider)
          .build()

        let sigv4LogExporter = try AwsSigV4LogRecordExporter.builder()
          .setRegion(region: region)
          .setServiceName(serviceName: "rum")
          .setCredentialsProvider(credentialsProvider: credentialsProvider)
          .build()

        // Configure AWS OpenTelemetry with SigV4 exporters
        let awsConfig = AwsConfig(region: region, rumAppMonitorId: "your-app-monitor-id")
        let config = AwsOpenTelemetryConfig(
          aws: awsConfig,
          otelResourceAttributes: [
            "service.version": "1.0.0",
            "service.name": "YourApp"
          ]
        )

        AwsOpenTelemetryRumBuilder.create(config: config)?
          .addSpanExporterCustomizer { _ in sigv4SpanExporter }
          .addLogRecordExporterCustomizer { _ in sigv4LogExporter }
          .build()

      } catch {
        print("Failed to setup AWS SigV4 exporters: \(error)")
      }
    }
  }
}
```
