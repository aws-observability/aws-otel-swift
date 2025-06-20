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

import AWSClientRuntime
import AWSCognitoIdentity

import SmithyIdentity

/**
 * Provider for AWS credentials using Amazon Cognito Identity
 *
 * This class handles the retrieval and caching of AWS credentials from
 * Amazon Cognito Identity service using the specified identity pool.
 *
 * Reference: https://docs.aws.amazon.com/sdk-for-swift/latest/developer-guide/using-identity.html
 */
@MainActor
public class AwsCredentialsProvider {
  /// The Cognito identity pool ID used for authentication
  let cognitoPoolId: String

  /// Client for interacting with the Amazon Cognito Identity service
  let cognitoIdentityClient: CognitoIdentityClient!

  /// Cached identity ID to avoid unnecessary API calls
  private var cachedIdentityId: String?

  /**
   * Initializes the AWS credentials provider
   *
   * - Parameters:
   *   - cognitoPoolId: The Cognito identity pool ID to use for authentication
   *   - region: The AWS region where the Cognito identity pool is located
   *
   * - Throws: Error if unable to initialize the Cognito Identity client
   */
  public init(cognitoPoolId: String, region: String) async throws {
    self.cognitoPoolId = cognitoPoolId

    // Configure and initialize the Cognito Identity client
    let cognitoConfig = try await CognitoIdentityClient.CognitoIdentityClientConfiguration(region: region)
    cognitoIdentityClient = CognitoIdentityClient(config: cognitoConfig)
  }

  /**
   * Fetches the Cognito identity ID for the current user
   *
   * This method will use a cached identity ID if available, otherwise
   * it will make an API call to retrieve a new identity ID.
   *
   * - Returns: The Cognito identity ID as a string
   * - Throws: FetchCredentialError.noIdentityId if no identity ID is returned
   */
  private func fetchIdentityId() async throws -> String {
    // Return cached ID if available to reduce API calls
    if let cached = cachedIdentityId {
      return cached
    }

    // Make API call to get a new identity ID
    let output = try await cognitoIdentityClient.getId(input: GetIdInput(identityPoolId: cognitoPoolId))
    guard let id = output.identityId else { throw FetchCredentialError.noIdentityId }

    // Cache the identity ID for future use
    cachedIdentityId = id
    return id
  }

  /**
   * Fetches temporary AWS credentials for the specified identity ID
   *
   * - Parameter identityId: The Cognito identity ID to get credentials for
   * - Returns: Temporary AWS credentials including access key, secret key, and session token
   * - Throws: FetchCredentialError.noCredentials if no credentials are returned
   */
  private func fetchCredentials(identityId: String) async throws -> CognitoIdentityClientTypes.Credentials {
    let output = try await cognitoIdentityClient.getCredentialsForIdentity(
      input: GetCredentialsForIdentityInput(identityId: identityId)
    )
    guard let creds = output.credentials else { throw FetchCredentialError.noCredentials }
    return creds
  }

  /**
   * Creates an AWS credential identity resolver that can be used with AWS service clients
   *
   * This method handles the complete flow of retrieving an identity ID and then
   * getting temporary credentials for that identity.
   *
   * - Returns: A StaticAWSCredentialIdentityResolver that can be used to configure AWS service clients
   * - Throws: Errors from fetchIdentityId() or fetchCredentials() if credential retrieval fails
   */
  public func getCredentialIdentityResolver() async throws -> StaticAWSCredentialIdentityResolver {
    // Get the identity ID (cached or new)
    let identityId = try await fetchIdentityId()

    // Get credentials for the identity ID
    let creds = try await fetchCredentials(identityId: identityId)

    // Create and return the credential identity resolver
    let awsCredentials = AWSCredentialIdentity(
      accessKey: creds.accessKeyId ?? "",
      secret: creds.secretKey ?? "",
      sessionToken: creds.sessionToken
    )
    return try StaticAWSCredentialIdentityResolver(awsCredentials)
  }
}
