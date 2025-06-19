#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { AwsOtelSwiftSimpleAwsDemoAppStack } from './lib/aws-otel-swift-simple-aws-demo-app-stack';

const app = new cdk.App();
new AwsOtelSwiftSimpleAwsDemoAppStack(app, 'AwsOtelSwiftSimpleAwsDemoAppStack');
