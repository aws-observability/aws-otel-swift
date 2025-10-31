import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as rum from 'aws-cdk-lib/aws-rum';

export class AwsOtelSwiftSimpleAwsDemoAppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create an S3 bucket for the demo app
    const demoBucket = new s3.Bucket(this, 'AwsOtelSwiftDemoBucket', {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      versioned: false,
      publicReadAccess: false,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
    });

    // Create a Cognito Identity Pool
    const identityPool = new cognito.CfnIdentityPool(this, 'AwsOtelSwiftDemoIdentityPool', {
      allowUnauthenticatedIdentities: true, // Allow unauthenticated identities for demo purposes
      identityPoolName: 'aws-otel-swift-demo-identity-pool',
    });

    // Create IAM roles for authenticated and unauthenticated users
    const unauthenticatedRole = new iam.Role(this, 'CognitoUnauthenticatedRole', {
      assumedBy: new iam.FederatedPrincipal(
        'cognito-identity.amazonaws.com',
        {
          StringEquals: {
            'cognito-identity.amazonaws.com:aud': identityPool.ref,
          },
          'ForAnyValue:StringLike': {
            'cognito-identity.amazonaws.com:amr': 'unauthenticated',
          },
        },
        'sts:AssumeRoleWithWebIdentity',
      ),
    });

    const authenticatedRole = new iam.Role(this, 'CognitoAuthenticatedRole', {
      assumedBy: new iam.FederatedPrincipal(
        'cognito-identity.amazonaws.com',
        {
          StringEquals: {
            'cognito-identity.amazonaws.com:aud': identityPool.ref,
          },
          'ForAnyValue:StringLike': {
            'cognito-identity.amazonaws.com:amr': 'authenticated',
          },
        },
        'sts:AssumeRoleWithWebIdentity',
      ),
    });

    // Create a CloudWatch RUM AppMonitor for OpenTelemetry
    const appMonitor = new rum.CfnAppMonitor(this, 'AwsOtelSwiftDemoAppMonitor', {
      domain: 'amazonaws.com',
      name: 'aws-otel-swift-demo-app-monitor',
      appMonitorConfiguration: {
        allowCookies: false,
        enableXRay: true,
        sessionSampleRate: 1,
        telemetries: ['errors', 'performance', 'http'],
      },
    });

    // Add S3 permissions to roles
    unauthenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['s3:ListBucket'],
        resources: [demoBucket.bucketArn],
      }),
    );

    unauthenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['s3:ListAllMyBuckets'],
        resources: ['*'],
      }),
    );

    authenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['s3:ListBucket', 's3:GetObject', 's3:PutObject'],
        resources: [demoBucket.bucketArn, `${demoBucket.bucketArn}/*`],
      }),
    );

    authenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['s3:ListAllMyBuckets'],
        resources: ['*'],
      }),
    );

    // Add CloudWatch RUM permissions to both roles
    const rumPolicy = new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['rum:PutRumEvents'],
      resources: [`arn:aws:rum:${this.region}:${this.account}:appmonitor/${appMonitor.name}`],
    });

    // Attach CloudWatchAgentServerPolicy to both roles for OTLP endpoints
    unauthenticatedRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName('CloudWatchAgentServerPolicy'),
    );

    authenticatedRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName('CloudWatchAgentServerPolicy'),
    );

    // Add RUM policy to both roles
    unauthenticatedRole.addToPolicy(rumPolicy);
    authenticatedRole.addToPolicy(rumPolicy);

    // Attach roles to the Identity Pool
    new cognito.CfnIdentityPoolRoleAttachment(this, 'IdentityPoolRoleAttachment', {
      identityPoolId: identityPool.ref,
      roles: {
        authenticated: authenticatedRole.roleArn,
        unauthenticated: unauthenticatedRole.roleArn,
      },
    });

    // Output the Identity Pool ID and AppMonitor ID for use in the Swift app
    new cdk.CfnOutput(this, 'IdentityPoolId', {
      value: identityPool.ref,
      description: 'The ID of the Cognito Identity Pool',
      exportName: 'AwsOtelSwiftDemoIdentityPoolId',
    });

    new cdk.CfnOutput(this, 'AppMonitorId', {
      value: appMonitor.attrId,
      description: 'The ID of the CloudWatch RUM AppMonitor',
      exportName: 'AwsOtelSwiftDemoAppMonitorId',
    });

    new cdk.CfnOutput(this, 'DemoBucketName', {
      value: demoBucket.bucketName,
      description: 'The name of the S3 bucket',
      exportName: 'AwsOtelSwiftDemoBucketName',
    });

    new cdk.CfnOutput(this, 'Region', {
      value: this.region,
      description: 'The AWS region',
      exportName: 'AwsOtelSwiftDemoRegion',
    });
  }
}
