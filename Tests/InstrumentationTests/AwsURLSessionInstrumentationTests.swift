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
  // Shared components for all tests to ensure proper isolation
  static var sharedInstrumentation: AwsURLSessionInstrumentation?
  static var sharedSpanProcessor: TestSpanProcessor?
  static var sharedTracerProvider: TracerProvider?

  override class func setUp() {
    super.setUp()

    // Create shared span processor
    sharedSpanProcessor = TestSpanProcessor()

    // Create shared tracer provider
    sharedTracerProvider = TracerProviderBuilder()
      .add(spanProcessor: sharedSpanProcessor!)
      .build()

    // Register the shared tracer provider globally ONCE
    OpenTelemetry.registerTracerProvider(tracerProvider: sharedTracerProvider!)

    let rumConfig = RumConfig(
      region: "us-west-2",
      appMonitorId: "test-app-monitor-id"
    )
    sharedInstrumentation = AwsURLSessionInstrumentation(config: rumConfig)

    // Apply instrumentation after OpenTelemetry is initialized (matches production flow)
    sharedInstrumentation?.apply()
  }

  override class func tearDown() {
    sharedInstrumentation = nil
    sharedSpanProcessor = nil
    sharedTracerProvider = nil
    super.tearDown()
  }

  override func setUp() {
    super.setUp()
    // Clear spans before each test but keep the same TracerProvider
    Self.sharedSpanProcessor?.clear()
  }

  // MARK: - Functional Tests

  func testOTLPEndpointsFiltering() async throws {
    // Use shared components
    guard let spanProcessor = Self.sharedSpanProcessor else {
      XCTFail("Shared span processor should exist")
      return
    }

    spanProcessor.clear()

    // Make request to the default RUM endpoint (should be filtered out)
    let rumEndpointURL = URL(string: "https://dataplane.rum.us-west-2.amazonaws.com/v1/rum/events")!
    let rumRequest = URLRequest(url: rumEndpointURL)

    let expectation = XCTestExpectation(description: "RUM endpoint request completed")

    let task = URLSession.shared.dataTask(with: rumRequest) { _, _, _ in
      expectation.fulfill()
    }
    task.resume()

    await fulfillment(of: [expectation], timeout: 10.0)
    try await Task.sleep(nanoseconds: 1_000_000_000)

    let spans = spanProcessor.getFinishedSpans()

    // Filter for spans that might be related to our RUM endpoint request
    let rumSpans = spans.filter { span in
      let spanData = span.toSpanData()
      let hasRumUrl = spanData.attributes.values.contains { value in
        value.description.contains("dataplane.rum.us-west-2.amazonaws.com")
      }
      return hasRumUrl
    }

    // Verify that RUM endpoints are NOT captured in spans
    XCTAssertEqual(rumSpans.count, 0, "RUM OTLP endpoints should be filtered and not create spans")
  }

  func testRegularRequestsAreInstrumented() async throws {
    try await telemetryForRegularRequests()
  }

  func testBasicInitialization() {
    // Test that instrumentation can be initialized and applied without errors
    let rumConfig = RumConfig(
      region: "us-east-1",
      appMonitorId: "test-initialization"
    )

    XCTAssertNoThrow({
      let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)
      instrumentation.apply()
    }, "AwsURLSessionInstrumentation should initialize and apply without throwing")
  }

  func testApplyIdempotency() async throws {
    // Test that calling apply() multiple times is safe
    let rumConfig = RumConfig(
      region: "eu-west-1",
      appMonitorId: "test-idempotency"
    )

    let instrumentation = AwsURLSessionInstrumentation(config: rumConfig)

    // Should be safe to call apply() multiple times
    XCTAssertNoThrow({
      instrumentation.apply()
      instrumentation.apply()
      instrumentation.apply()
    }, "Multiple apply() calls should be safe")

    try await telemetryForRegularRequests()
  }

  private func telemetryForRegularRequests() async throws {
    guard let spanProcessor = Self.sharedSpanProcessor else {
      XCTFail("Shared span processor should exist")
      return
    }
    spanProcessor.clear()

    // Make request to regular endpoint (should be instrumented)
    let testURL = URL(string: "https://httpbin.org/status/200")!
    let request = URLRequest(url: testURL)

    let expectation = XCTestExpectation(description: "Regular request completed")

    let task = URLSession.shared.dataTask(with: request) { _, _, _ in
      expectation.fulfill()
    }
    task.resume()

    await fulfillment(of: [expectation], timeout: 10.0)
    try await Task.sleep(nanoseconds: 2_000_000_000)

    let spans = spanProcessor.getFinishedSpans()

    // Filter for spans that are specifically from our test request
    let testSpans = spans.filter { span in
      let spanData = span.toSpanData()

      // Check if this span is related to our test URL
      let hasTestUrl = spanData.attributes.values.contains { value in
        value.description.contains("httpbin.org/status/200")
      }

      // Check if it's an HTTP span
      let isHttpSpan = spanData.name.contains("GET") ||
        spanData.name.contains("HTTP") ||
        spanData.attributes.keys.contains("http.method") ||
        spanData.attributes.keys.contains("http.request.method")

      return hasTestUrl && isHttpSpan
    }

    // Assert on test-specific spans only
    XCTAssertGreaterThan(testSpans.count, 0, "Test-specific HTTP spans should be created")
  }
}

// MARK: - Test Utilities

/**
 * Test span processor that captures spans for verification
 */
class TestSpanProcessor: SpanProcessor {
  private var finishedSpans: [ReadableSpan] = []
  private let lock = NSLock()

  var isStartRequired: Bool { false }
  var isEndRequired: Bool { true }

  func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    // No-op
  }

  func onEnd(span: ReadableSpan) {
    lock.lock()
    defer { lock.unlock() }
    finishedSpans.append(span)
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    // No-op
  }

  func forceFlush(timeout: TimeInterval?) {
    // No-op
  }

  func getFinishedSpans() -> [ReadableSpan] {
    lock.lock()
    defer { lock.unlock() }
    return Array(finishedSpans)
  }

  func clear() {
    lock.lock()
    defer { lock.unlock() }
    finishedSpans.removeAll()
  }
}
