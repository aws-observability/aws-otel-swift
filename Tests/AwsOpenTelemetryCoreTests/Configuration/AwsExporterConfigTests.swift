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
import OpenTelemetryProtocolExporterCommon

class AwsExporterConfigTests: XCTestCase {
  func testDefaultConfiguration() {
    let config = AwsExporterConfig.default

    XCTAssertEqual(config.maxRetries, 3)
    XCTAssertEqual(config.maxBatchSize, 100)
    XCTAssertEqual(config.maxQueueSize, 1048)
    XCTAssertEqual(config.batchInterval, 5.0)
    XCTAssertEqual(config.exportTimeout, 30.0)
    XCTAssertEqual(config.compression, .gzip)

    // Test retryable status codes include 429 and standard AWS 5xx codes
    XCTAssertTrue(config.retryableStatusCodes.contains(429))
    XCTAssertTrue(config.retryableStatusCodes.contains(500))
    XCTAssertTrue(config.retryableStatusCodes.contains(502))
    XCTAssertTrue(config.retryableStatusCodes.contains(503))
    XCTAssertTrue(config.retryableStatusCodes.contains(504))
    XCTAssertFalse(config.retryableStatusCodes.contains(404))
    XCTAssertFalse(config.retryableStatusCodes.contains(599))
  }

  func testCustomConfiguration() {
    let config = AwsExporterConfig(
      maxRetries: 5,
      retryableStatusCodes: Set([429, 503]),
      maxBatchSize: 50,
      maxQueueSize: 2000,
      batchInterval: 10.0,
      exportTimeout: 60.0,
      compression: .none
    )

    XCTAssertEqual(config.maxRetries, 5)
    XCTAssertEqual(config.retryableStatusCodes, Set([429, 503]))
    XCTAssertEqual(config.maxBatchSize, 50)
    XCTAssertEqual(config.maxQueueSize, 2000)
    XCTAssertEqual(config.batchInterval, 10.0)
    XCTAssertEqual(config.exportTimeout, 60.0)
    XCTAssertEqual(config.compression, .none)
  }

  func testBackoffCalculation() {
    let config = AwsExporterConfig.default

    // Test that retryable status codes are properly configured for AWS standard backoff
    XCTAssertTrue(config.retryableStatusCodes.contains(429)) // Rate limiting
    XCTAssertTrue(config.retryableStatusCodes.contains(500)) // Internal server error
    XCTAssertTrue(config.retryableStatusCodes.contains(502)) // Bad gateway
    XCTAssertTrue(config.retryableStatusCodes.contains(503)) // Service unavailable
    XCTAssertTrue(config.retryableStatusCodes.contains(504)) // Gateway timeout
  }

  func testInitializationWithDefaults() {
    let config = AwsExporterConfig()

    XCTAssertEqual(config.maxRetries, 3)
    XCTAssertEqual(config.retryableStatusCodes, Set([429, 500, 502, 503, 504]))
    XCTAssertEqual(config.maxBatchSize, 100)
    XCTAssertEqual(config.maxQueueSize, 1048)
    XCTAssertEqual(config.batchInterval, 5.0)
    XCTAssertEqual(config.exportTimeout, 30.0)
    XCTAssertEqual(config.compression, .gzip)
  }
}
