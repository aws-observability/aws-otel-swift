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

/// Ref: https://docs.aws.amazon.com/sdk-for-swift/latest/developer-guide/using-identity.html
@MainActor

public class AwsCredentialsProvider {
  let cognitoPoolId: String
  let cognitoIdentityClient: CognitoIdentityClient!

  private var cachedIdentityId: String?

  public init(cognitoPoolId: String, region: String) async throws {
    self.cognitoPoolId = cognitoPoolId

    let cognitoConfig = try await CognitoIdentityClient.CognitoIdentityClientConfiguration(region: region)
    cognitoIdentityClient = CognitoIdentityClient(config: cognitoConfig)
  }

  private func fetchIdentityId() async throws -> String {
    if let cached = cachedIdentityId {
      return cached
    }
    let output = try await cognitoIdentityClient.getId(input: GetIdInput(identityPoolId: cognitoPoolId))
    guard let id = output.identityId else { throw FetchCredentialError.noIdentityId }
    cachedIdentityId = id
    return id
  }

  private func fetchCredentials(identityId: String) async throws -> CognitoIdentityClientTypes.Credentials {
    let output = try await cognitoIdentityClient.getCredentialsForIdentity(
      input: GetCredentialsForIdentityInput(identityId: identityId)
    )
    guard let creds = output.credentials else { throw FetchCredentialError.noCredentials }
    return creds
  }

  public func getCredentialIdentityResolver() async throws -> StaticAWSCredentialIdentityResolver {
    let identityId = try await fetchIdentityId()
    let creds = try await fetchCredentials(identityId: identityId)

    let awsCredentials = AWSCredentialIdentity(
      accessKey: creds.accessKeyId ?? "",
      secret: creds.secretKey ?? "",
      sessionToken: creds.sessionToken
    )
    return try StaticAWSCredentialIdentityResolver(awsCredentials)
  }
}
