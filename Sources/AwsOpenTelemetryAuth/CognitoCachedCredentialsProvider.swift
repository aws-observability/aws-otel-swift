import Foundation
import AwsCommonRuntimeKit
import AWSCognitoIdentity
import SmithyIdentity
import Smithy

private let REFRESH_BUFFER_WINDOW_DEFAULT: TimeInterval = 10

public class CognitoCachedCredentialsProvider: CredentialsProviding {
  private let cognitoPoolId: String
  private let cognitoIdentityClient: CognitoIdentityClient
  private let loginsMap: [Swift.String: Swift.String]?
  private var cachedCredentials: CognitoIdentityClientTypes.Credentials?
  private let refreshBufferWindow: TimeInterval

  public init(cognitoPoolId: String, cognitoClient: CognitoIdentityClient, loginsMap: [Swift.String: Swift.String]? = nil, refreshBufferWindow: TimeInterval?) {
    self.cognitoPoolId = cognitoPoolId
    cognitoIdentityClient = cognitoClient
    self.loginsMap = loginsMap
    self.refreshBufferWindow = refreshBufferWindow ?? REFRESH_BUFFER_WINDOW_DEFAULT
  }

  public func getCredentials() async throws -> Credentials {
    if shouldUpdateCredentials() {
      let identityId = try await fetchIdentityId(client: cognitoIdentityClient)
      let credentials = try await fetchCredentials(client: cognitoIdentityClient, identityId: identityId)

      cachedCredentials = credentials
    }

    return try Credentials(
      accessKey: cachedCredentials?.accessKeyId ?? "",
      secret: cachedCredentials?.secretKey ?? "",
      sessionToken: cachedCredentials?.sessionToken,
      expiration: cachedCredentials?.expiration
    )
  }

  private func fetchIdentityId(client: CognitoIdentityClient) async throws -> String {
    let identityOutput = try await client.getId(
      input: GetIdInput(identityPoolId: cognitoPoolId, logins: loginsMap)
    )

    guard let identityId = identityOutput.identityId else {
      throw AwsOpenTelemetryAuthError.noIdentityId
    }
    return identityId
  }

  private func fetchCredentials(client: CognitoIdentityClient, identityId: String) async throws -> CognitoIdentityClientTypes.Credentials {
    let credentialsOutput = try await client.getCredentialsForIdentity(
      input: GetCredentialsForIdentityInput(identityId: identityId)
    )

    guard let credentials = credentialsOutput.credentials else {
      throw AwsOpenTelemetryAuthError.credentialsError
    }
    return credentials
  }

  private func shouldUpdateCredentials() -> Bool {
    let checkCredentials = cachedCredentials

    if checkCredentials?.expiration == nil {
      return true
    }

    if Date().addingTimeInterval(refreshBufferWindow) >= checkCredentials!.expiration! {
      return true
    }

    return false
  }
}
