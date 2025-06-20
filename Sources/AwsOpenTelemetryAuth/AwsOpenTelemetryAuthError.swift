/*
 * Copyright Amazon.com, Inc. or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import Foundation

/**
 * Errors that can occur during AWS OpenTelemetry authentication operations.
 *
 * This enum represents various authentication-related errors that may be encountered
 * when working with AWS Cognito Identity and credential providers in the AWS OpenTelemetry SDK.
 */
public enum AwsOpenTelemetryAuthError: Error, Equatable {
  /// Indicates that no identity ID could be retrieved from AWS Cognito Identity.
  case noIdentityId

  /// Indicates that AWS credentials could not be retrieved for the identity.
  case credentialsError
}
