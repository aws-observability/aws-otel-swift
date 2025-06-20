# AWS OpenTelemetry Swift Simple AWS Demo App Infrastructure

This CDK project creates the necessary AWS infrastructure for the AWS OpenTelemetry Swift Simple AWS Demo App.

## Infrastructure Components

- **Cognito Identity Pool**: Provides authentication and authorization for the iOS app
- **IAM Roles**: Defines permissions for authenticated and unauthenticated users with access to:
  - S3 operations
  - CloudWatch RUM PutRumEvents
  - CloudWatchAgentServerPolicy (for OTLP endpoints, X-Ray, and CloudWatch)
- **S3 Bucket**: A demo bucket that the app can access
- **CloudWatch RUM AppMonitor**: For OpenTelemetry instrumentation

## Deployment Instructions

### Prerequisites

- AWS CLI configured with appropriate credentials
- Node.js and npm installed
- AWS CDK installed (`npm install -g aws-cdk`)

### Steps to Deploy

1. Install requirements:
   - Node + NPM 
   - AWS CDK (https://docs.aws.amazon.com/cdk/v2/guide/getting-started.html)
2. Run `chmod +x ./demo-cdk.sh` to make the file executable, if needed.
3. (Optional) Run `./demo-cdk.sh synth` to bootstrap and synthesize CDK stack(s)
4. Run `./demo-cdk.sh deploy` to deploy CDK stack(s) with valid environment credentials
5. Note the outputs from the deployment as they will be needed to update the `SimpleAwsDemoApp.swift` file in your iOS app:
   - IdentityPoolId: Use this in your iOS app's SimpleAwsDemoApp.swift
   - AppMonitorId: Use this in your iOS app's SimpleAwsDemoApp.swift
   - Region: Use this in your iOS app's SimpleAwsDemoApp.swift
   - DemoBucketName: Optional, for additional S3 operations

## Cleanup

To remove all resources created by this stack:

```
./demo-cdk.sh destroy
```

Note: This will delete all resources including the S3 bucket and its contents.
