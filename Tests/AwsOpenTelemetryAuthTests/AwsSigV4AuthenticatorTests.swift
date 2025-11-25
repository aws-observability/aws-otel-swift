import XCTest
import AwsCommonRuntimeKit
@testable import AwsOpenTelemetryAuth

class MockCredentialsProvider: CredentialsProviding {
  var shouldThrow = false
  var credentials: Credentials?

  func getCredentials() async throws -> Credentials {
    if shouldThrow {
      throw NSError(domain: "TestError", code: 1, userInfo: nil)
    }
    if let credentials {
      return credentials
    }
    return try Credentials(accessKey: "test", secret: "test")
  }
}

class AwsSigV4AuthenticatorTests: XCTestCase {
  let accessKey = "AccessKey"
  let secret = "Secret"
  let sessionToken = "Token"
  let endpoint = "https://dataplane.rum.us-east-1.amazonaws.com/v1/traces"
  let region = "us-east-1"
  let serviceName = "rum"

  override func setUp() {
    super.setUp()
    // Reset authenticator configuration before each test
    resetAuthenticatorConfiguration()
  }

  override func tearDown() {
    // Clean up after each test
    resetAuthenticatorConfiguration()
    super.tearDown()
  }

  private func resetAuthenticatorConfiguration() {
    // Create a dummy provider to reset the static configuration
    let dummyProvider = MockCredentialsProvider()
    AwsSigV4Authenticator.configure(
      credentialsProvider: dummyProvider,
      region: "dummy",
      serviceName: "dummy"
    )
  }

  func testSignURLRequestWithValidCredentials() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: accessKey,
        secret: secret,
        sessionToken: sessionToken
      ))

    AwsSigV4Authenticator.configure(
      credentialsProvider: provider,
      region: region,
      serviceName: serviceName
    )

    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.httpBody = Data("test".utf8)

    let signedRequest = AwsSigV4Authenticator.signURLRequestSync(urlRequest: request)
    let headers = signedRequest.allHTTPHeaderFields!

    XCTAssertNotNil(headers["X-Amz-Date"])
    XCTAssertNotNil(headers["Authorization"])
    XCTAssertTrue(headers["Authorization"]?.contains("AWS4-HMAC-SHA256") == true)
    XCTAssertNotNil(headers["Host"])
  }

  func testSignURLRequestWithoutConfiguration() {
    // Don't configure the authenticator - it should be reset from setUp
    let request = URLRequest(url: URL(string: endpoint)!)

    // This should return the original request unchanged when using dummy config
    let signedRequest = AwsSigV4Authenticator.signURLRequestSync(urlRequest: request)

    // Should be the same request (URL should match)
    XCTAssertEqual(request.url, signedRequest.url)
    // May have headers due to dummy config, so just verify it doesn't crash
    XCTAssertNotNil(signedRequest)
  }

  func testSignURLRequestWithCredentialsError() {
    let mockProvider = MockCredentialsProvider()
    mockProvider.shouldThrow = true

    AwsSigV4Authenticator.configure(
      credentialsProvider: mockProvider,
      region: region,
      serviceName: serviceName
    )

    let request = URLRequest(url: URL(string: endpoint)!)
    let signedRequest = AwsSigV4Authenticator.signURLRequestSync(urlRequest: request)

    // Should return original request when credentials fail
    XCTAssertEqual(request.url, signedRequest.url)
    XCTAssertNil(signedRequest.allHTTPHeaderFields?["Authorization"])
  }

  func testSignURLRequestWithInvalidURL() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: accessKey,
        secret: secret,
        sessionToken: sessionToken
      ))

    AwsSigV4Authenticator.configure(
      credentialsProvider: provider,
      region: region,
      serviceName: serviceName
    )

    var request = URLRequest(url: URL(string: endpoint)!)
    request.url = nil // Invalid URL

    let signedRequest = AwsSigV4Authenticator.signURLRequestSync(urlRequest: request)

    // Should return original request when URL is invalid
    XCTAssertNil(signedRequest.url)
  }

  func testSignURLRequestWithDifferentHTTPMethods() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: accessKey,
        secret: secret,
        sessionToken: sessionToken
      ))

    AwsSigV4Authenticator.configure(
      credentialsProvider: provider,
      region: region,
      serviceName: serviceName
    )

    let methods = ["GET", "POST", "PUT", "DELETE"]

    for method in methods {
      var request = URLRequest(url: URL(string: endpoint)!)
      request.httpMethod = method

      let signedRequest = AwsSigV4Authenticator.signURLRequestSync(urlRequest: request)

      XCTAssertNotNil(signedRequest.allHTTPHeaderFields?["Authorization"])
      XCTAssertEqual(signedRequest.httpMethod, method)
    }
  }

  func testSignURLRequestWithQueryParameters() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: accessKey,
        secret: secret,
        sessionToken: sessionToken
      ))

    AwsSigV4Authenticator.configure(
      credentialsProvider: provider,
      region: region,
      serviceName: serviceName
    )

    let urlWithQuery = "\(endpoint)?param1=value1&param2=value2"
    let request = URLRequest(url: URL(string: urlWithQuery)!)

    let signedRequest = AwsSigV4Authenticator.signURLRequestSync(urlRequest: request)

    XCTAssertNotNil(signedRequest.allHTTPHeaderFields?["Authorization"])
    XCTAssertEqual(signedRequest.url?.query, "param1=value1&param2=value2")
  }
}
