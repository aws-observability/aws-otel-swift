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

import XCTest
import Foundation
@testable import AwsOpenTelemetryAuth

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

final class HTTPClientWithSessionTests: XCTestCase {
  var mockSession: MockURLSession!
  var httpClient: HTTPClientWithSession!

  override func setUp() {
    super.setUp()
    mockSession = MockURLSession(configuration: .default)
    httpClient = HTTPClientWithSession(session: mockSession)
  }

  func testInitialization() {
    let session = URLSession.shared
    let client = HTTPClientWithSession(session: session)
    XCTAssertNotNil(client)
  }

  func testSendRequestSuccess() {
    let expectation = expectation(description: "Request completion")
    let expectedResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!

    mockSession.mockResponse = expectedResponse

    let request = URLRequest(url: URL(string: "https://example.com")!)

    httpClient.send(request: request) { result in
      switch result {
      case let .success(response):
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.url, URL(string: "https://example.com"))
      case .failure:
        XCTFail("Expected success but got failure")
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
    XCTAssertTrue(mockSession.dataTaskCalled)
    XCTAssertEqual(mockSession.lastRequest, request)
  }

  func testSendRequestWithError() {
    let expectation = expectation(description: "Request completion")
    let expectedError = NSError(domain: "TestError", code: 123, userInfo: nil)

    mockSession.mockError = expectedError

    let request = URLRequest(url: URL(string: "https://example.com")!)

    httpClient.send(request: request) { result in
      switch result {
      case .success:
        XCTFail("Expected failure but got success")
      case let .failure(error):
        XCTAssertEqual((error as NSError).code, 123)
        XCTAssertEqual((error as NSError).domain, "TestError")
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testSendRequestWithInvalidResponse() {
    let expectation = expectation(description: "Request completion")
    let invalidResponse = URLResponse(url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)

    mockSession.mockResponse = invalidResponse

    let request = URLRequest(url: URL(string: "https://example.com")!)

    httpClient.send(request: request) { result in
      switch result {
      case .success:
        XCTFail("Expected failure but got success")
      case let .failure(error):
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, "HTTPClientError")
        XCTAssertEqual(nsError.code, -1)
        XCTAssertEqual(nsError.localizedDescription, "Invalid response type")
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }
}

// MARK: - Mock Classes

class MockURLSession: URLSession, @unchecked Sendable {
  var dataTaskCalled = false
  var lastRequest: URLRequest?
  var mockResponse: URLResponse?
  var mockError: Error?

  init(configuration: URLSessionConfiguration) {
    super.init()
  }

  override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
    dataTaskCalled = true
    lastRequest = request

    let task = MockURLSessionDataTask {
      completionHandler(nil, self.mockResponse, self.mockError)
    }

    return task
  }
}

class MockURLSessionDataTask: URLSessionDataTask, @unchecked Sendable {
  private let completion: () -> Void

  init(completion: @escaping () -> Void) {
    self.completion = completion
    super.init()
  }

  override func resume() {
    completion()
  }
}
