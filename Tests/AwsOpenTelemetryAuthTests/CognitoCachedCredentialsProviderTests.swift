import XCTest
@testable import AwsOpenTelemetryAuth
import AWSCognitoIdentity

class CognitoCachedCredentialsProviderTests: XCTestCase {
  func testShouldUpdateCredentials_WhenCredentialsAreNil() {
    let result = CognitoCachedCredentialsProvider.shouldUpdateCredentials(
      cachedCredentials: nil,
      refreshBufferWindow: 10
    )

    XCTAssertTrue(result, "Should update when credentials are nil")
  }

  func testShouldUpdateCredentials_WhenExpirationIsNil() {
    let credentials = CognitoIdentityClientTypes.Credentials(
      accessKeyId: "test-access-key",
      secretKey: "test-secret-key",
      sessionToken: "test-session-token"
    )

    let result = CognitoCachedCredentialsProvider.shouldUpdateCredentials(
      cachedCredentials: credentials,
      refreshBufferWindow: 10
    )

    XCTAssertTrue(result, "Should update when expiration is nil")
  }

  func testShouldUpdateCredentials_WhenCredentialsExpired() {
    let expiredDate = Date().addingTimeInterval(-100) // 100 seconds ago
    let credentials = CognitoIdentityClientTypes.Credentials(
      accessKeyId: "test-access-key",
      expiration: expiredDate,
      secretKey: "test-secret-key",
      sessionToken: "test-session-token"
    )

    let result = CognitoCachedCredentialsProvider.shouldUpdateCredentials(
      cachedCredentials: credentials,
      refreshBufferWindow: 10,
      currentDate: Date()
    )

    XCTAssertTrue(result, "Should update when credentials are expired")
  }

  func testShouldUpdateCredentials_WhenWithinBufferWindow() {
    let soonToExpireDate = Date().addingTimeInterval(5)
    let credentials = CognitoIdentityClientTypes.Credentials(
      accessKeyId: "test-access-key",
      expiration: soonToExpireDate,
      secretKey: "test-secret-key",
      sessionToken: "test-session-token"
    )

    let result = CognitoCachedCredentialsProvider.shouldUpdateCredentials(
      cachedCredentials: credentials,
      refreshBufferWindow: 10,
      currentDate: Date()
    )

    XCTAssertTrue(result, "Should update when within buffer window")
  }

  func testShouldUpdateCredentials_WhenStillValid() {
    let validDate = Date().addingTimeInterval(60)
    let credentials = CognitoIdentityClientTypes.Credentials(
      accessKeyId: "test-access-key",
      expiration: validDate,
      secretKey: "test-secret-key",
      sessionToken: "test-session-token"
    )

    let result = CognitoCachedCredentialsProvider.shouldUpdateCredentials(
      cachedCredentials: credentials,
      refreshBufferWindow: 10,
      currentDate: Date()
    )

    XCTAssertFalse(result, "Should not update when credentials are still valid")
  }

  func testShouldUpdateCredentials_WithCustomBufferWindow() {
    let credentialsDate = Date().addingTimeInterval(25)
    let credentials = CognitoIdentityClientTypes.Credentials(
      accessKeyId: "test-access-key",
      expiration: credentialsDate,
      secretKey: "test-secret-key",
      sessionToken: "test-session-token"
    )

    let result = CognitoCachedCredentialsProvider.shouldUpdateCredentials(
      cachedCredentials: credentials,
      refreshBufferWindow: 30,
      currentDate: Date()
    )

    XCTAssertTrue(result, "Should update when within custom buffer window")
  } Add commentMore actions
}
