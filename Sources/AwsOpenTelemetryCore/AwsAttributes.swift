/*
 * Copyright Amazon.com, Inc. or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import Foundation

enum AwsAttributes: String {
  /** RUM attributes */
  /// Attribute key for the AWS RUM AppMonitor ID
  case rumAppMonitorId = "aws.rum.appmonitor.id"

  /// Attribute key for the AWS RUM AppMonitor alias
  case rumAppMonitorAlias = "aws.rum.appmonitor.alias"

  /// Attribute key for the aws-otel-swift sdk version
  case rumSdkVersion = "rum.sdk.version"

  /** Cloud attributes */
  case awsRumCloudPlatform = "aws_rum"
  case awsCloudProvider = "aws"
}
