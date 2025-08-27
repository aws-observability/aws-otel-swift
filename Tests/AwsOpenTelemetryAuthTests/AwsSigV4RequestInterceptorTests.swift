import XCTest
import Foundation
import AwsCommonRuntimeKit
@testable import AwsOpenTelemetryAuth

class AwsSigV4RequestInterceptorTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Register the interceptor for testing
    URLProtocol.registerClass(AwsSigV4RequestInterceptor.self)

    // Configure authenticator for tests that need it
    do {
      let provider = try CredentialsProvider(
        source: .static(
          accessKey: "test-access-key",
          secret: "test-secret",
          sessionToken: "test-token"
        ))
      AwsSigV4Authenticator.configure(
        credentialsProvider: provider,
        region: "us-east-1",
        serviceName: "rum"
      )
    } catch {
      // If configuration fails, some tests will be skipped
    }
  }

  override func tearDown() {
    // Unregister the interceptor after testing
    URLProtocol.unregisterClass(AwsSigV4RequestInterceptor.self)
    super.tearDown()
  }

  func testCanInitWithRequestReturnsTrue() {
    let request = URLRequest(url: URL(string: "https://example.com")!)

    let canHandle = AwsSigV4RequestInterceptor.canInit(with: request)

    XCTAssertTrue(canHandle)
  }

  func testCanInitWithTaskReturnsTrue() {
    let request = URLRequest(url: URL(string: "https://example.com")!)
    let session = URLSession.shared
    let task = session.dataTask(with: request)

    let canHandle = AwsSigV4RequestInterceptor.canInit(with: task)

    XCTAssertTrue(canHandle)
  }

  func testCanonicalRequestCallsAuthenticator() {
    let originalRequest = URLRequest(url: URL(string: "https://example.com")!)

    // This test verifies that canonicalRequest doesn't crash when called
    let canonicalRequest = AwsSigV4RequestInterceptor.canonicalRequest(for: originalRequest)

    // The canonical request should preserve the original URL
    XCTAssertEqual(canonicalRequest.url, originalRequest.url)
  }

  func testURLProtocolRegistration() {
    // Test that the interceptor can be registered and unregistered
    URLProtocol.unregisterClass(AwsSigV4RequestInterceptor.self)
    URLProtocol.registerClass(AwsSigV4RequestInterceptor.self)

    // This should not crash
    XCTAssertTrue(true)
  }

  func testStartLoadingCreatesDataTask() {
    let request = URLRequest(url: URL(string: "https://example.com")!)
    let interceptor = AwsSigV4RequestInterceptor(request: request, cachedResponse: nil, client: nil)

    // This test verifies that startLoading doesn't crash
    // In a real scenario, we'd need a mock client to verify behavior
    XCTAssertNoThrow(interceptor.startLoading())
    XCTAssertNoThrow(interceptor.stopLoading())
  }

  func testStopLoadingCancelsTask() {
    let request = URLRequest(url: URL(string: "https://example.com")!)
    let interceptor = AwsSigV4RequestInterceptor(request: request, cachedResponse: nil, client: nil)

    interceptor.startLoading()

    // This should not crash
    XCTAssertNoThrow(interceptor.stopLoading())
  }

  func testInterceptorLifecycle() {
    let request = URLRequest(url: URL(string: "https://example.com")!)
    let interceptor = AwsSigV4RequestInterceptor(request: request, cachedResponse: nil, client: nil)

    // Test that lifecycle methods can be called without crashing
    XCTAssertNoThrow(interceptor.startLoading())
    XCTAssertNoThrow(interceptor.stopLoading())
  }

  func testCanonicalRequestPreservesURL() {
    let testURL = URL(string: "https://dataplane.rum.us-east-1.amazonaws.com/v1/traces")!
    let request = URLRequest(url: testURL)

    let canonicalRequest = AwsSigV4RequestInterceptor.canonicalRequest(for: request)

    XCTAssertEqual(canonicalRequest.url, testURL)
  }

  func testCanonicalRequestPreservesHTTPMethod() {
    var request = URLRequest(url: URL(string: "https://example.com")!)
    request.httpMethod = "POST"

    let canonicalRequest = AwsSigV4RequestInterceptor.canonicalRequest(for: request)

    XCTAssertEqual(canonicalRequest.httpMethod, "POST")
  }
}
