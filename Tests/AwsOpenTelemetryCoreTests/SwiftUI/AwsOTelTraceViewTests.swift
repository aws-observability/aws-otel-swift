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
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let traceView = AwsOTelTraceView("TestView") {
      Text("Test Content")
    }

    // First trigger appear to create root span
    traceView.handleViewAppear()

    // Then access body to create body span
    _ = traceView.body

    let spans = mockSpanProcessor.getEndedSpans()
    let bodySpans = spans.filter { $0.name == AwsViewConstants.spanNameBody }
    XCTAssertGreaterThan(bodySpans.count, 0, "Should have at least one body span")

    // Verify screen.name attribute on body span
    let bodySpan = bodySpans.first!
    XCTAssertEqual(bodySpan.attributes[AwsViewConstants.attributeScreenName]?.description, "TestView")
  }

  func testHandleViewAppear() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let traceView = AwsOTelTraceView("TestView") {
      Text("Test Content")
    }

    traceView.handleViewAppear()

    let spans = mockSpanProcessor.getEndedSpans()
    let startedSpans = mockSpanProcessor.getStartedSpans()
    XCTAssertEqual(spans.count, 2) // TimeToFirstAppear + onAppear
    XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.TimeToFirstAppear })
    XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameOnAppear })

    // Verify TimeToFirstAppear span has root span as parent
    let timeToFirstAppearSpan = spans.first { $0.name == AwsViewConstants.TimeToFirstAppear }
    let rootSpan = startedSpans.first { $0.name == AwsViewConstants.spanNameView }
    XCTAssertNotNil(timeToFirstAppearSpan)
    XCTAssertNotNil(rootSpan)
    XCTAssertEqual(timeToFirstAppearSpan?.parentSpanId, rootSpan?.spanId)
    XCTAssertEqual(timeToFirstAppearSpan?.attributes[AwsViewConstants.attributeScreenName]?.description, "TestView")

    let onAppearSpan = spans.first { $0.name == AwsViewConstants.spanNameOnAppear }
    XCTAssertNotNil(onAppearSpan)
    XCTAssertEqual(onAppearSpan?.attributes[AwsViewConstants.attributeScreenName]?.description, "TestView")
  }

  func testHandleViewDisappear() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let traceView = AwsOTelTraceView("TestView") {
      Text("Test Content")
    }

    traceView.handleViewAppear()
    traceView.handleViewDisappear()

    let spans = mockSpanProcessor.getEndedSpans()
    XCTAssertEqual(spans.count, 5) // TimeToFirstAppear + onAppear + onDisappear + root + view.duration
    XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.TimeToFirstAppear })
    XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameOnAppear })
    XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameOnDisappear })
    XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameView })
    XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameTimeOnScreen })

    // Verify screen.name attribute is set on all spans
    let expectedSpanNames = [AwsViewConstants.TimeToFirstAppear, AwsViewConstants.spanNameOnAppear, AwsViewConstants.spanNameOnDisappear, AwsViewConstants.spanNameView, AwsViewConstants.spanNameTimeOnScreen]
    let allSpans = spans.filter { expectedSpanNames.contains($0.name) }
    for span in allSpans {
      XCTAssertEqual(span.attributes[AwsViewConstants.attributeScreenName]?.description, "TestView", "Span \(span.name) should have screen.name attribute")
    }
  }

  func testViewDurationSpan() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let traceView = AwsOTelTraceView("TestView") {
      Text("Test Content")
    }

    traceView.handleViewAppear()
    traceView.handleViewDisappear()

    let spans = mockSpanProcessor.getEndedSpans()
    let durationSpans = spans.filter { $0.name == AwsViewConstants.spanNameTimeOnScreen }
    XCTAssertEqual(durationSpans.count, 1, "Should have exactly one view.duration span")

    let durationSpan = durationSpans.first!
    XCTAssertEqual(durationSpan.attributes[AwsViewConstants.attributeScreenName]?.description, "TestView")
    XCTAssertEqual(durationSpan.attributes[AwsViewConstants.attributeViewType]?.description, AwsViewConstants.valueSwiftUI)

    let duration = durationSpan.endTime.timeIntervalSince(durationSpan.startTime)
    XCTAssertGreaterThanOrEqual(duration, 0, "Duration span should measure at least 0 seconds")
  }

  func testTraceViewAttributesAppliedToSpans() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
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
    traceView.handleViewDisappear()

    let spans = mockSpanProcessor.getEndedSpans()
    let viewSpans = spans.filter { $0.name == AwsViewConstants.spanNameView }
    XCTAssertEqual(viewSpans.count, 1)

    let viewSpan = viewSpans.first!
    XCTAssertEqual(viewSpan.attributes["screen_type"]?.description, "test")
    XCTAssertEqual(viewSpan.attributes["user_id"]?.description, "123")
    XCTAssertEqual(viewSpan.attributes["is_premium"]?.description, "true")
    XCTAssertEqual(viewSpan.attributes["score"]?.description, "98.5")
    XCTAssertEqual(viewSpan.attributes[AwsViewConstants.attributeScreenName]?.description, "TestView")
  }
}
