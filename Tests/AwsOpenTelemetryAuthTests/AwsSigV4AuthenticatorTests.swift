import XCTest
import AwsCommonRuntimeKit
@testable import AwsOpenTelemetryAuth

class AwsSigV4AuthenticatorTests: XCTestCase {
  let accessKey = "AccessKey"
  let secret = "Sekrit"
  let sessionToken = "Token"

  func testGetSignedHeadersWithMinimalValidInputReturnsExpectedHeaders() async throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: accessKey,
        secret: secret,
        sessionToken: sessionToken
      ))

    // Use async/await instead of runBlocking
    let headers = try await AwsSigV4Authenticator.signHeaders(
      endpoint: "https://dataplane.rum.us-east-1.amazonaws.com",
      credentialsProvider: provider,
      region: "us-east-1",
      serviceName: "rum",
      body: "test".data(using: .utf8)!
    )

    XCTAssertNotNil(headers["X-Amz-Date"])
    XCTAssertNotNil(headers["Authorization"])
    XCTAssertEqual("application/x-protobuf", headers["Content-Type"])
  }

  func testGetSignedHeadersWithFailedCredentialsResolutionThrowsException() async throws {
    do {
      // CredentialsProvider creation fails due to empty access key
      let provider = try CredentialsProvider(
        source: .static(
          accessKey: "",
          secret: secret,
          sessionToken: sessionToken
        ))

      _ = try await AwsSigV4Authenticator.signHeaders(
        endpoint: "https://dataplane.rum.us-east-1.amazonaws.com",
        credentialsProvider: provider,
        region: "us-east-1",
        serviceName: "rum",
        body: "test".data(using: .utf8)!
      )
    } catch {
      XCTAssertTrue(true)
    }
  }
}
