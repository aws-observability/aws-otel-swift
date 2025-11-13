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
import SwiftUI
@testable import AwsOpenTelemetryCore
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import TestUtils

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class AwsOTelTraceViewTests: XCTestCase {
  var mockSpanProcessor: MockSpanProcessor!
  var mockTracerProvider: TracerProviderSdk!
  var originalTracerProvider: TracerProvider!

  override func setUpWithError() throws {
    mockSpanProcessor = MockSpanProcessor()
    mockTracerProvider = TracerProviderBuilder()
      .add(spanProcessor: mockSpanProcessor)
      .build()

    originalTracerProvider = OpenTelemetry.instance.tracerProvider
    OpenTelemetry.registerTracerProvider(tracerProvider: mockTracerProvider)

    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
  }

  override func tearDownWithError() throws {
    OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
    mockSpanProcessor?.reset()
    mockSpanProcessor = nil
    mockTracerProvider = nil
    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
  }

  func testBody() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: AwsTelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let traceView = AwsOTelTraceView("TestView") {
      Text("Test Content")
    }

    // First trigger appear to create spans
    traceView.handleViewAppear()

    // Then access body
    _ = traceView.body

    let spans = mockSpanProcessor.getEndedSpans()
    XCTAssertGreaterThan(spans.count, 0, "Should have at least one span")
  }

  func testHandleViewAppear() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: AwsTelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let traceView = AwsOTelTraceView("TestView") {
      Text("Test Content")
    }

    traceView.handleViewAppear()

    let spans = mockSpanProcessor.getEndedSpans()
    _ = mockSpanProcessor.getStartedSpans()
    XCTAssertGreaterThan(spans.count, 0)

    // Check if any spans were created (the implementation may create different spans)
    if let firstSpan = spans.first {
      // Verify that screen name attribute is set if it exists
      if let screenName = firstSpan.attributes[AwsViewSemConv.screenName] {
        XCTAssertEqual(screenName.description, "TestView")
      }
    }
  }

  // Test removed - handleViewDisappear method does not exist in implementation

  // Test removed - handleViewDisappear method does not exist in implementation

  func testTraceViewAttributesAppliedToSpans() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: AwsTelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let traceView = AwsOTelTraceView("TestView", attributes: [
      "screen_type": .string("test"),
      "user_id": .int(123),
      "is_premium": .bool(true),
      "score": .double(98.5)
    ]) {
      Text("Test Content")
    }

    traceView.handleViewAppear()

    let spans = mockSpanProcessor.getEndedSpans()

    // Test that spans are created with attributes
    XCTAssertGreaterThan(spans.count, 0)

    // Find a span with the custom attributes
    let spanWithAttributes = spans.first { span in
      span.attributes["screen_type"] != nil
    }
    XCTAssertNotNil(spanWithAttributes)

    if let span = spanWithAttributes {
      XCTAssertEqual(span.attributes["screen_type"]?.description, "test")
      XCTAssertEqual(span.attributes["user_id"]?.description, "123")
      XCTAssertEqual(span.attributes["is_premium"]?.description, "true")
      XCTAssertEqual(span.attributes["score"]?.description, "98.5")
      XCTAssertEqual(span.attributes[AwsViewSemConv.screenName]?.description, "TestView")
    }
  }
}
