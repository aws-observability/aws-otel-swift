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
@testable import AwsOpenTelemetryCore
@testable import TestUtils

class AwsHttpClientTests: XCTestCase {
  func testSuccessfulRequest() {
    let expectation = XCTestExpectation(description: "HTTP request succeeds")
    let mockSession = MockURLSession()
    let config = AwsExporterConfig(maxRetries: 2)
    let httpClient = AwsHttpClient(config: config, session: mockSession)
    let request = URLRequest(url: URL(string: "https://example.com")!)

    mockSession.mockResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)

    httpClient.send(request: request) { result in
      switch result {
      case let .success(response):
        XCTAssertEqual(response.statusCode, 200)
        expectation.fulfill()
      case .failure:
        XCTFail("Expected success")
      }
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testRetryOnRetryableStatusCode() {
    let expectation = XCTestExpectation(description: "HTTP request retries on 500")
    let mockSession = MockURLSession()
    let config = AwsExporterConfig(maxRetries: 1, retryableStatusCodes: Set([500]))
    let httpClient = AwsHttpClient(config: config, session: mockSession)
    let request = URLRequest(url: URL(string: "https://example.com")!)

    mockSession.mockResponse = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)

    httpClient.send(request: request) { result in
      switch result {
      case let .success(response):
        XCTAssertEqual(response.statusCode, 500)
        XCTAssertEqual(mockSession.requestCount, 2) // Original + 1 retry
        expectation.fulfill()
      case .failure:
        XCTFail("Expected success")
      }
    }

    wait(for: [expectation], timeout: 3.0)
  }

  func testNoRetryOnNonRetryableStatusCode() {
    let expectation = XCTestExpectation(description: "HTTP request doesn't retry on 404")
    let mockSession = MockURLSession()
    let config = AwsExporterConfig(maxRetries: 2, retryableStatusCodes: Set([500]))
    let httpClient = AwsHttpClient(config: config, session: mockSession)
    let request = URLRequest(url: URL(string: "https://example.com")!)

    mockSession.mockResponse = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)

    httpClient.send(request: request) { result in
      switch result {
      case let .success(response):
        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(mockSession.requestCount, 1) // No retries
        expectation.fulfill()
      case .failure:
        XCTFail("Expected success")
      }
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testRetryOnNetworkError() {
    let expectation = XCTestExpectation(description: "HTTP request retries on network error")
    let mockSession = MockURLSession()
    let config = AwsExporterConfig(maxRetries: 1)
    let httpClient = AwsHttpClient(config: config, session: mockSession)
    let request = URLRequest(url: URL(string: "https://example.com")!)

    mockSession.mockError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: nil)

    httpClient.send(request: request) { result in
      switch result {
      case .success:
        XCTFail("Expected failure")
      case let .failure(error):
        XCTAssertEqual((error as NSError).code, NSURLErrorNetworkConnectionLost)
        XCTAssertEqual(mockSession.requestCount, 2) // Original + 1 retry
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 3.0)
  }
}
