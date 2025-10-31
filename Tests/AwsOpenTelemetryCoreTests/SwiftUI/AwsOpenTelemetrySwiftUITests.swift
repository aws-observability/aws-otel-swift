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
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import TestUtils

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class AwsOpenTelemetrySwiftUITests: XCTestCase {
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

  // MARK: - Span Creation Tests

  func testtimeToFirstAppearSpanCreated() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    let appearTime = Date()
    let initTime = Date().addingTimeInterval(-1)
    let timeToFirstAppearSpan = tracer.spanBuilder(spanName: "TestView.TimeToFirstAppear")
      .setSpanKind(spanKind: .client)
      .setStartTime(time: initTime)
      .startSpan()

    let durationNanos = Double(10 * 1_000_000_000)
    timeToFirstAppearSpan.setAttribute(key: "view.lifecycle", value: "TimeToFirstAppear")
    timeToFirstAppearSpan.setAttribute(key: "durationNanos", value: durationNanos)
    timeToFirstAppearSpan.end(time: appearTime)

    let spans = mockSpanProcessor.getEndedSpans()
    XCTAssertEqual(spans.count, 1)

    let ttfdSpan = spans.first!
    XCTAssertEqual(ttfdSpan.name, "TestView.TimeToFirstAppear")
    XCTAssertEqual(ttfdSpan.getAttributeString("view.lifecycle"), "TimeToFirstAppear")
    XCTAssertNotNil(ttfdSpan.getAttributeDouble("durationNanos"))
    XCTAssertTrue(ttfdSpan.getAttributeDouble("durationNanos")! > 0)
  }

  func testtimeToFirstAppearOnlyCreatedOnFirstAppear() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")
    let initTime = Date().addingTimeInterval(-1)
    var appearCount = 0

    for _ in 0 ..< 3 {
      let appearTime = Date()

      if appearCount == 0 {
        let timeToFirstAppearSpan = tracer.spanBuilder(spanName: "TestView.TimeToFirstAppear")
          .setSpanKind(spanKind: .client)
          .setStartTime(time: initTime)
          .startSpan()

        let durationNanos = Double(appearTime.timeIntervalSince(initTime) * 1_000_000_000)
        timeToFirstAppearSpan.setAttribute(key: "view.lifecycle", value: "TimeToFirstAppear")
        timeToFirstAppearSpan.setAttribute(key: "durationNanos", value: durationNanos)
        timeToFirstAppearSpan.end(time: appearTime)
      }

      appearCount += 1
    }

    let spans = mockSpanProcessor.getEndedSpans()
    let ttfdSpans = spans.filter { $0.name.contains("TimeToFirstAppear") }
    XCTAssertEqual(ttfdSpans.count, 1, "Should only create one TimeToFirstAppear span")
  }

  func testCustomAttributesHandling() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    let span = tracer.spanBuilder(spanName: "TestView").startSpan()
    span.setAttribute(key: "screen_type", value: "test")
    span.setAttribute(key: "user_id", value: "12345")
    span.setAttribute(key: "is_premium", value: true)
    span.setAttribute(key: "item_count", value: 42)
    span.end()

    let spans = mockSpanProcessor.getEndedSpans()
    XCTAssertEqual(spans.count, 1)

    let testSpan = spans.first!
    XCTAssertEqual(testSpan.getAttributeString("screen_type"), "test")
    XCTAssertEqual(testSpan.getAttributeString("user_id"), "12345")
    XCTAssertEqual(testSpan.getAttributeBool("is_premium"), true)
    XCTAssertEqual(testSpan.getAttributeInt("item_count"), 42)
  }
}
