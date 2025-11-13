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
import OpenTelemetrySdk
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import OpenTelemetryProtocolExporterCommon
@testable import AwsOpenTelemetryCore
@testable import TestUtils

class AwsRetryableSpanExporterTests: XCTestCase {
  func testInitialization() {
    let endpoint = URL(string: "https://example.com/traces")!
    let config = AwsExporterConfig.default
    let exporter = AwsRetryableSpanExporter(endpoint: endpoint, config: config)

    XCTAssertNotNil(exporter)
  }

  func testExportEmptySpans() {
    let endpoint = URL(string: "https://example.com/traces")!
    let exporter = AwsRetryableSpanExporter(endpoint: endpoint)

    let result = exporter.export(spans: [], explicitTimeout: TimeInterval?.none)
    XCTAssertEqual(result, SpanExporterResultCode.success)
  }

  func testExportWithMockHttpClient() {
    let mockSession = MockURLSession()
    let config = AwsExporterConfig(maxRetries: 1)
    let endpoint = URL(string: "https://example.com/traces")!

    let httpClient = AwsHttpClient(config: config, session: mockSession)
    let exporter = AwsRetryableSpanExporter(endpoint: endpoint, config: config, httpClient: httpClient)

    mockSession.mockResponse = HTTPURLResponse(url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)

    let spanData = TestSpanData()
    let result = exporter.export(spans: [spanData], explicitTimeout: TimeInterval?.none)

    XCTAssertEqual(result, SpanExporterResultCode.success)

    let expectation = XCTestExpectation(description: "Request made")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      XCTAssertEqual(mockSession.requestCount, 1)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)
  }

  func testExportWithRetryOnFailure() {
    let mockSession = MockURLSession()
    let config = AwsExporterConfig(maxRetries: 2, retryableStatusCodes: Set([503]))
    let endpoint = URL(string: "https://example.com/traces")!

    let httpClient = AwsHttpClient(config: config, session: mockSession)
    let exporter = AwsRetryableSpanExporter(endpoint: endpoint, config: config, httpClient: httpClient)

    mockSession.mockResponse = HTTPURLResponse(url: endpoint, statusCode: 503, httpVersion: nil, headerFields: nil)

    let spanData = TestSpanData()
    let result = exporter.export(spans: [spanData], explicitTimeout: TimeInterval?.none)

    XCTAssertEqual(result, SpanExporterResultCode.success)

    let expectation = XCTestExpectation(description: "Retries completed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
      XCTAssertEqual(mockSession.requestCount, 3)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 6.0)
  }

  func testFlush() {
    let endpoint = URL(string: "https://example.com/traces")!
    let exporter = AwsRetryableSpanExporter(endpoint: endpoint)

    let result = exporter.flush(explicitTimeout: TimeInterval?.none)
    XCTAssertEqual(result, SpanExporterResultCode.success)
  }

  func testShutdown() {
    let endpoint = URL(string: "https://example.com/traces")!
    let exporter = AwsRetryableSpanExporter(endpoint: endpoint)

    exporter.shutdown(explicitTimeout: TimeInterval?.none)
  }
}
