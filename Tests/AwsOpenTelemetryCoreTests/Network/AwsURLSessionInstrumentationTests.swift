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
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import AwsOpenTelemetryCore

final class AwsURLSessionInstrumentationTests: XCTestCase {
  func testOTLPEndpointsFiltering() {
    let config = AwsURLSessionConfig(region: "us-west-2")
    let instrumentation = AwsURLSessionInstrumentation(config: config)

    let rumRequest = URLRequest(url: URL(string: "https://dataplane.rum.us-west-2.amazonaws.com/v1/rum/events")!)
    XCTAssertTrue(instrumentation.shouldExcludeURL(rumRequest), "RUM endpoints should be excluded")
  }

  func testRegularRequestsAreNotFiltered() {
    let config = AwsURLSessionConfig(region: "us-west-2")
    let instrumentation = AwsURLSessionInstrumentation(config: config)

    let regularRequest = URLRequest(url: URL(string: "https://httpbin.org/status/200")!)
    XCTAssertFalse(instrumentation.shouldExcludeURL(regularRequest), "Regular endpoints should not be excluded")
  }

  func testBasicInitialization() {
    let config = AwsURLSessionConfig(region: "us-east-1")

    XCTAssertNoThrow({
      let instrumentation = AwsURLSessionInstrumentation(config: config)
      instrumentation.apply()
    }, "AwsURLSessionInstrumentation should initialize and apply without throwing")
  }

  func testApplyIdempotency() {
    let config = AwsURLSessionConfig(region: "us-west-2")
    let instrumentation = AwsURLSessionInstrumentation(config: config)

    XCTAssertNoThrow({
      instrumentation.apply()
      instrumentation.apply()
      instrumentation.apply()
    }, "Multiple apply() calls should be safe")
  }

  func testCustomEndpointFiltering() {
    let exportOverride = AwsExportOverride(
      logs: "https://custom-logs.example.com",
      traces: "https://custom-traces.example.com"
    )
    let config = AwsURLSessionConfig(region: "us-west-2", exportOverride: exportOverride)
    let instrumentation = AwsURLSessionInstrumentation(config: config)

    let customLogsRequest = URLRequest(url: URL(string: "https://custom-logs.example.com/logs")!)
    let customTracesRequest = URLRequest(url: URL(string: "https://custom-traces.example.com/traces")!)

    XCTAssertTrue(instrumentation.shouldExcludeURL(customLogsRequest), "Custom logs endpoint should be excluded")
    XCTAssertTrue(instrumentation.shouldExcludeURL(customTracesRequest), "Custom traces endpoint should be excluded")
  }

  func testRequestWithNilURL() {
    let config = AwsURLSessionConfig(region: "us-west-2")
    let instrumentation = AwsURLSessionInstrumentation(config: config)

    var mutableRequest = URLRequest(url: URL(string: "https://example.com")!)
    mutableRequest.url = nil

    XCTAssertFalse(instrumentation.shouldExcludeURL(mutableRequest), "Request with nil URL should not be excluded")
  }

  func testPrefixMatching() {
    let config = AwsURLSessionConfig(region: "us-west-2")
    let instrumentation = AwsURLSessionInstrumentation(config: config)

    let rumSubpathRequest = URLRequest(url: URL(string: "https://dataplane.rum.us-west-2.amazonaws.com/v1/rum/events/subpath")!)
    XCTAssertTrue(instrumentation.shouldExcludeURL(rumSubpathRequest), "RUM endpoint subpaths should be excluded")
  }
}
