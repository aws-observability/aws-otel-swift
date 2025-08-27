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
@testable import AwsURLSessionInstrumentation
@testable import AwsOpenTelemetryCore

final class AwsURLSessionInstrumentationTests: XCTestCase {
  func testOTLPEndpointsFiltering() {
    let rumConfig = RumConfig(region: "us-west-2", appMonitorId: "test-app-monitor-id")
    let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)

    let rumRequest = URLRequest(url: URL(string: "https://dataplane.rum.us-west-2.amazonaws.com/v1/rum/events")!)
    XCTAssertTrue(instrumentation.shouldExcludeURL(rumRequest), "RUM endpoints should be excluded")
  }

  func testRegularRequestsAreNotFiltered() {
    let rumConfig = RumConfig(region: "us-west-2", appMonitorId: "test-app-monitor-id")
    let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)

    let regularRequest = URLRequest(url: URL(string: "https://httpbin.org/status/200")!)
    XCTAssertFalse(instrumentation.shouldExcludeURL(regularRequest), "Regular endpoints should not be excluded")
  }

  func testBasicInitialization() {
    let rumConfig = RumConfig(region: "us-east-1", appMonitorId: "test-initialization")

    XCTAssertNoThrow({
      let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)
      instrumentation.apply()
    }, "AwsURLSessionInstrumentation should initialize and apply without throwing")
  }

  func testApplyIdempotency() {
    let rumConfig = RumConfig(region: "us-west-2", appMonitorId: "test-app-monitor-id")
    let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)

    XCTAssertNoThrow({
      instrumentation.apply()
      instrumentation.apply()
      instrumentation.apply()
    }, "Multiple apply() calls should be safe")
  }

  func testCustomEndpointFiltering() {
    let overrideEndpoint = EndpointOverrides(
      logs: "https://custom-logs.example.com",
      traces: "https://custom-traces.example.com"
    )
    let rumConfig = RumConfig(
      region: "us-west-2",
      appMonitorId: "test-app-monitor-id",
      overrideEndpoint: overrideEndpoint
    )
    let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)

    let customLogsRequest = URLRequest(url: URL(string: "https://custom-logs.example.com/logs")!)
    let customTracesRequest = URLRequest(url: URL(string: "https://custom-traces.example.com/traces")!)

    XCTAssertTrue(instrumentation.shouldExcludeURL(customLogsRequest), "Custom logs endpoint should be excluded")
    XCTAssertTrue(instrumentation.shouldExcludeURL(customTracesRequest), "Custom traces endpoint should be excluded")
  }

  func testRequestWithNilURL() {
    let rumConfig = RumConfig(region: "us-west-2", appMonitorId: "test-app-monitor-id")
    let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)

    var mutableRequest = URLRequest(url: URL(string: "https://example.com")!)
    mutableRequest.url = nil

    XCTAssertFalse(instrumentation.shouldExcludeURL(mutableRequest), "Request with nil URL should not be excluded")
  }

  func testPrefixMatching() {
    let rumConfig = RumConfig(region: "us-west-2", appMonitorId: "test-app-monitor-id")
    let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)

    let rumSubpathRequest = URLRequest(url: URL(string: "https://dataplane.rum.us-west-2.amazonaws.com/v1/rum/events/subpath")!)
    XCTAssertTrue(instrumentation.shouldExcludeURL(rumSubpathRequest), "RUM endpoint subpaths should be excluded")
  }
}
