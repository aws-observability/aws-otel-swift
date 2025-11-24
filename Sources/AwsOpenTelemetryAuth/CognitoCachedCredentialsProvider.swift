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
import AwsCommonRuntimeKit
import AWSCognitoIdentity
import AwsOpenTelemetryCore

/**
 * A credentials provider that retrieves AWS credentials from Amazon Cognito Identity
 * and caches them to avoid unnecessary API calls.
 *
 * This provider implements the `CredentialsProviding` protocol and manages the lifecycle
 * of AWS credentials obtained through Cognito Identity pools. It automatically refreshes
 * credentials when they are close to expiration based on a configurable buffer window.
 *
 */
public class CognitoCachedCredentialsProvider: CredentialsProviding {
  /// The Cognito Identity Pool ID used to retrieve credentials
  private let cognitoPoolId: String

  /// The Cognito Identity client used for API calls
  private let cognitoIdentityClient: CognitoIdentityClient

  /// Optional map of identity provider names to login tokens for authenticated access
  private let loginsMap: [Swift.String: Swift.String]?

  /// Cached credentials to avoid unnecessary API calls
  private var cachedCredentials: CognitoIdentityClientTypes.Credentials?

  /// Time buffer before expiration when credentials should be refreshed
  private let refreshBufferWindow: TimeInterval

  /// Default refresh buffer window of 10 seconds
  public static let REFRESH_BUFFER_WINDOW_DEFAULT: TimeInterval = 10

  /**
   * Initializes a new CognitoCachedCredentialsProvider.
   *
   * - Parameters:
   *   - cognitoPoolId: The Amazon Cognito Identity Pool ID. This should be in the format
   *                    "region:pool-id"
   *   - cognitoClient: An initialized CognitoIdentityClient for making API calls
   *   - loginsMap: Optional dictionary mapping identity provider names to login tokens.
   *                Used for authenticated access. Keys should be provider names like
   *                "graph.facebook.com" or "www.amazon.com", values should be the tokens.
   *   - refreshBufferWindow: Time interval in seconds before credential expiration when
   *                         they should be refreshed. Defaults to 10 seconds.
   *
   */
  public init(cognitoPoolId: String,
              cognitoClient: CognitoIdentityClient,
              loginsMap: [Swift.String: Swift.String]? = nil,
              refreshBufferWindow: TimeInterval = CognitoCachedCredentialsProvider.REFRESH_BUFFER_WINDOW_DEFAULT) {
    self.cognitoPoolId = cognitoPoolId
    cognitoIdentityClient = cognitoClient
    self.loginsMap = loginsMap
    self.refreshBufferWindow = refreshBufferWindow
    AwsInternalLogger.debug("Initializing CognitoCachedCredentialsProvider with poolId: \(cognitoPoolId), refreshBuffer: \(refreshBufferWindow)s")
  }

  /**
   * Retrieves AWS credentials, either from cache or by fetching new ones from Cognito.
   *
   * This method implements the `CredentialsProviding` protocol. It first checks if cached
   * credentials exist and are still valid (not expired within the refresh buffer window).
   * If credentials need to be refreshed, it fetches a new identity ID and credentials
   * from Amazon Cognito Identity service.
   *
   * - Returns: A `Credentials` object containing the access key, secret key, session token,
   *           and expiration time
   * - Throws:
   *   - `AwsOpenTelemetryAuthError.noIdentityId` if unable to retrieve identity ID
   *   - `AwsOpenTelemetryAuthError.credentialsError` if unable to retrieve credentials
   */
  public func getCredentials() async throws -> Credentials {
    if Self.shouldUpdateCredentials(
      cachedCredentials: cachedCredentials,
      refreshBufferWindow: refreshBufferWindow
    ) {
      AwsInternalLogger.debug("CognitoCachedCredentialsProvider fetching new credentials")
      let identityId = try await fetchIdentityId(client: cognitoIdentityClient)
      let credentials = try await fetchCredentialsForIdentity(client: cognitoIdentityClient, identityId: identityId)

      cachedCredentials = credentials
      AwsInternalLogger.debug("CognitoCachedCredentialsProvider cached new credentials")
    } else {
      AwsInternalLogger.debug("CognitoCachedCredentialsProvider using cached credentials")
    }

    return try Credentials(
      accessKey: cachedCredentials?.accessKeyId ?? "",
      secret: cachedCredentials?.secretKey ?? "",
      sessionToken: cachedCredentials?.sessionToken,
      expiration: cachedCredentials?.expiration
    )
  }

  /**
   * Fetches a unique identity ID from Amazon Cognito Identity service.
   *
   * This method calls the Cognito Identity `getId` operation to retrieve a unique
   * identity ID for the configured identity pool. The identity ID is used to
   * subsequently fetch AWS credentials.
   *
   * - Parameter client: The CognitoIdentityClient to use for the API call
   * - Returns: A string containing the unique identity ID
   * - Throws:
   *   - `AwsOpenTelemetryAuthError.noIdentityId` if the response doesn't contain an identity ID
   */
  private func fetchIdentityId(client: CognitoIdentityClient) async throws -> String {
    AwsInternalLogger.debug("CognitoCachedCredentialsProvider fetching identity ID")
    let identityOutput = try await client.getId(
      input: GetIdInput(identityPoolId: cognitoPoolId, logins: loginsMap)
    )

    guard let identityId = identityOutput.identityId else {
      AwsInternalLogger.debug("CognitoCachedCredentialsProvider failed to get identity ID")
      throw AwsOpenTelemetryAuthError.noIdentityId
    }
    AwsInternalLogger.debug("CognitoCachedCredentialsProvider got identity ID: \(identityId)")
    return identityId
  }

  /**
   * Fetches AWS credentials from Amazon Cognito Identity service using an identity ID.
   *
   * This method calls the Cognito Identity `getCredentialsForIdentity` operation to
   * retrieve temporary AWS credentials (access key, secret key, session token) that
   * can be used to access AWS services.
   *
   * - Parameters:
   *   - client: The CognitoIdentityClient to use for the API call
   *   - identityId: The unique identity ID obtained from `fetchIdentityId`
   * - Returns: A `CognitoIdentityClientTypes.Credentials` object containing the AWS credentials
   * - Throws:
   *   - `AwsOpenTelemetryAuthError.credentialsError` if the response doesn't contain credentials
   */
  private func fetchCredentialsForIdentity(client: CognitoIdentityClient, identityId: String) async throws -> CognitoIdentityClientTypes.Credentials {
    AwsInternalLogger.debug("CognitoCachedCredentialsProvider fetching credentials for identity: \(identityId)")
    let credentialsOutput = try await client.getCredentialsForIdentity(
      input: GetCredentialsForIdentityInput(identityId: identityId)
    )

    guard let credentials = credentialsOutput.credentials else {
      AwsInternalLogger.debug("CognitoCachedCredentialsProvider failed to get credentials")
      throw AwsOpenTelemetryAuthError.credentialsError
    }
    AwsInternalLogger.debug("CognitoCachedCredentialsProvider got credentials with expiration: \(credentials.expiration?.description ?? "none")")
    return credentials
  }
}

extension CognitoCachedCredentialsProvider {
  /**
   * Static utility method to determine if credentials should be updated.
   *
   * ## Logic Flow
   *
   * The function evaluates credentials refresh necessity using the following decision tree:
   *
   * 1. **No cached credentials**: Returns `true` (immediate refresh needed)
   * 2. **No expiration date**: Returns `true` (cannot determine validity, refresh for safety)
   * 3. **Has expiration date**: Compares `currentDate + refreshBufferWindow >= expiration`
   *    - If true: Returns `true` (refresh needed - within buffer window or expired)
   *    - If false: Returns `false` (credentials still valid outside buffer window)
   *
   * - Parameters:
   *   - cachedCredentials: The currently cached credentials, or nil if none exist
   *   - refreshBufferWindow: Time interval in seconds before expiration when refresh should occur.
   *   - currentDate: The current date/time to compare against expiration (defaults to Date()).
   * - Returns: `true` if credentials should be refreshed, `false` if they're still valid
   */
  static func shouldUpdateCredentials(cachedCredentials: CognitoIdentityClientTypes.Credentials?,
                                      refreshBufferWindow: TimeInterval,
                                      currentDate: Date = Date()) -> Bool {
    guard let credentials = cachedCredentials,
          let expiration = credentials.expiration else {
      return true
    }

    return currentDate.addingTimeInterval(refreshBufferWindow) >= expiration
  }
}
