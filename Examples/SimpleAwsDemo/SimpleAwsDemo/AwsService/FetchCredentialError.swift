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
 * Error types that can occur when fetching AWS credentials
 *
 * These errors provide specific information about what went wrong during
 * the credential retrieval process from Amazon Cognito Identity.
 */
public enum FetchCredentialError: Error, Equatable {
  /**
   * Indicates that no Cognito identity ID was returned
   *
   * This can happen if the identity pool is misconfigured or if there
   * are network connectivity issues when contacting the Cognito service.
   */
  case noIdentityId

  /**
   * Indicates failure in retrieving credentials for a valid identity ID
   *
   * This can happen if the identity doesn't have proper permissions or
   * if there are issues with the Cognito identity pool configuration.
   */
  case noCredentials
}
