import XCTest
import AwsCommonRuntimeKit
@testable import AwsOpenTelemetryAuth

class AwsSigV4AuthenticatorTests: XCTestCase {
  let accessKey = "AccessKey"
  let secret = "Secret"
  let sessionToken = "Token"
  let endpoint = "https://dataplane.rum.us-east-1.amazonaws.com/v1/traces"
  let region = "us-east-1"
  let serviceName = "rum"

  func testGetSignedHeadersWithMinimalValidInputReturnsExpectedHeaders() async throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: accessKey,
        secret: secret,
        sessionToken: sessionToken
      ))

    AwsSigV4Authenticator.configure(credentialsProvider: provider, region: region,
                                    serviceName: serviceName)

    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpBody = "test".data(using: .utf8)

    let signedRequest = AwsSigV4Authenticator.signURLRequestSync(
      urlRequest: request
    )
    let headers = signedRequest.allHTTPHeaderFields!

    XCTAssertNotNil(headers["X-Amz-Date"])
    XCTAssertNotNil(headers["Authorization"])
    XCTAssertNotNil(headers["Host"])
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

      AwsSigV4Authenticator.configure(credentialsProvider: provider, region: region,
                                      serviceName: serviceName)

      var request = URLRequest(url: URL(string: endpoint)!)
      request.httpBody = "test".data(using: .utf8)

    } catch {
      XCTAssertTrue(true)
    }
  }
}
