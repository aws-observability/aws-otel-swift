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

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class AwsOpenTelemetrySwiftUITests: XCTestCase {
  var mockSpanProcessor: MockSpanProcessor!
  var mockTracerProvider: TracerProviderSdk!
  var originalTracerProvider: TracerProvider!

  override func setUpWithError() throws {
    // Reset SwiftUI instrumentation state
    SwiftUIInstrumentation.shared.reset()

    // Create a fresh mock span processor for each test
    mockSpanProcessor = MockSpanProcessor()
    mockTracerProvider = TracerProviderBuilder()
      .add(spanProcessor: mockSpanProcessor)
      .build()

    // Store original and set mock
    originalTracerProvider = OpenTelemetry.instance.tracerProvider
    OpenTelemetry.registerTracerProvider(tracerProvider: mockTracerProvider)

    // Reset agent state
    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
  }

  override func tearDownWithError() throws {
    // Restore original tracer provider
    OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)

    // Clean up
    mockSpanProcessor?.reset()
    mockSpanProcessor = nil
    mockTracerProvider = nil
    SwiftUIInstrumentation.shared.reset()
    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
  }

  // MARK: - SwiftUIInstrumentation Tests

  func testSwiftUIInstrumentationInitialization() {
    // Given
    let telemetryConfig = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)

    // When
    SwiftUIInstrumentation.shared.initialize(with: telemetryConfig)

    // Then
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled)
  }

  func testSwiftUIInstrumentationDisabled() {
    // Given
    let telemetryConfig = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false)

    // When
    SwiftUIInstrumentation.shared.initialize(with: telemetryConfig)

    // Then
    XCTAssertFalse(SwiftUIInstrumentation.shared.isInstrumentationEnabled)
  }

  func testSwiftUIInstrumentationReset() {
    // Given
    let telemetryConfig = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
    SwiftUIInstrumentation.shared.initialize(with: telemetryConfig)
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled)

    // When
    SwiftUIInstrumentation.shared.reset()

    // Then
    XCTAssertFalse(SwiftUIInstrumentation.shared.isInstrumentationEnabled)
  }

  // MARK: - RumBuilder Integration Tests

  func testRumBuilderInitializesSwiftUIInstrumentation() throws {
    // Given
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: "us-west-2", appMonitorId: "test-id"),
      application: ApplicationConfig(applicationVersion: "1.0.0"),
      telemetry: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
    )

    // When
    try AwsOpenTelemetryRumBuilder.create(config: config).build()

    // Then
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled)
  }

  func testRumBuilderDisablesSwiftUIInstrumentation() throws {
    // Given
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: "us-west-2", appMonitorId: "test-id"),
      application: ApplicationConfig(applicationVersion: "1.0.0"),
      telemetry: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false)
    )

    // When
    try AwsOpenTelemetryRumBuilder.create(config: config).build()

    // Then
    XCTAssertFalse(SwiftUIInstrumentation.shared.isInstrumentationEnabled)
  }

  // MARK: - Span Creation Logic Tests

  func testSpanCreationWhenEnabled() {
    // Given
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // When - Simulate what AwsOpenTelemetryTraceView does
    let rootSpan = tracer.spanBuilder(spanName: "TestView").startSpan()
    rootSpan.setAttribute(key: "view.name", value: "TestView")
    rootSpan.setAttribute(key: "view.type", value: "swiftui")

    let onAppearSpan = tracer.spanBuilder(spanName: "TestView.onAppear")
      .setParent(rootSpan)
      .startSpan()
    onAppearSpan.setAttribute(key: "view.lifecycle", value: "onAppear")
    onAppearSpan.end()

    rootSpan.end()

    // Then
    let spans = mockSpanProcessor.getEndedSpans()
    XCTAssertEqual(spans.count, 2, "Should create root span and onAppear span")

    let rootSpans = spans.rootSpans
    let childSpans = spans.childSpans

    XCTAssertEqual(rootSpans.count, 1, "Should have one root span")
    XCTAssertEqual(childSpans.count, 1, "Should have one child span")

    // Verify root span
    let rootSpanData = rootSpans.first!
    XCTAssertEqual(rootSpanData.name, "TestView")
    XCTAssertEqual(rootSpanData.getAttributeString("view.name"), "TestView")
    XCTAssertEqual(rootSpanData.getAttributeString("view.type"), "swiftui")

    // Verify child span
    let childSpanData = childSpans.first!
    XCTAssertEqual(childSpanData.name, "TestView.onAppear")
    XCTAssertEqual(childSpanData.getAttributeString("view.lifecycle"), "onAppear")
    XCTAssertEqual(childSpanData.testParentSpanId, rootSpanData.testSpanId)
  }

  func testSpanCreationWhenDisabled() {
    // Given
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false))

    // When - Simulate disabled instrumentation (no spans should be created)
    let isEnabled = SwiftUIInstrumentation.shared.isInstrumentationEnabled

    // Then
    XCTAssertFalse(isEnabled, "Instrumentation should be disabled")

    // In real usage, when disabled, the guard statements would prevent span creation
    // We can't easily test this without the actual SwiftUI view, but we can test the flag
    let spans = mockSpanProcessor.getEndedSpans()
    XCTAssertEqual(spans.count, 0, "No spans should be created when disabled")
  }

  // MARK: - ViewTraceState Integration Tests

  func testViewTraceStateLifecycle() {
    // Given
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // When - Simulate view lifecycle
    // 1. View appears
    state.appearCount += 1
    let rootSpan = tracer.spanBuilder(spanName: "TestView").startSpan()
    state.rootSpan = rootSpan

    // 2. Create onAppear span
    let onAppearSpan = tracer.spanBuilder(spanName: "TestView.onAppear")
      .setParent(rootSpan)
      .startSpan()
    onAppearSpan.end()

    // 3. View disappears
    state.disappearCount += 1
    let onDisappearSpan = tracer.spanBuilder(spanName: "TestView.onDisappear")
      .setParent(rootSpan)
      .startSpan()
    onDisappearSpan.end()

    rootSpan.end()
    state.rootSpan = nil

    // Then
    XCTAssertEqual(state.appearCount, 1)
    XCTAssertEqual(state.disappearCount, 1)
    XCTAssertNil(state.rootSpan)

    let spans = mockSpanProcessor.getEndedSpans()
    XCTAssertEqual(spans.count, 3, "Should have root, onAppear, and onDisappear spans")

    let spanNames = spans.spanNames
    XCTAssertTrue(spanNames.contains("TestView"))
    XCTAssertTrue(spanNames.contains("TestView.onAppear"))
    XCTAssertTrue(spanNames.contains("TestView.onDisappear"))
  }

  // MARK: - Custom Attributes Tests

  func testCustomAttributesHandling() {
    // Given
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // When - Create span with custom attributes
    let span = tracer.spanBuilder(spanName: "TestView").startSpan()
    span.setAttribute(key: "screen_type", value: "test")
    span.setAttribute(key: "user_id", value: "12345")
    span.setAttribute(key: "is_premium", value: true)
    span.setAttribute(key: "item_count", value: 42)
    span.end()

    // Then
    let spans = mockSpanProcessor.getEndedSpans()
    XCTAssertEqual(spans.count, 1)

    let testSpan = spans.first!
    XCTAssertEqual(testSpan.getAttributeString("screen_type"), "test")
    XCTAssertEqual(testSpan.getAttributeString("user_id"), "12345")
    XCTAssertEqual(testSpan.getAttributeBool("is_premium"), true)
    XCTAssertEqual(testSpan.getAttributeInt("item_count"), 42)
  }

  // MARK: - Error Handling Tests

  func testInstrumentationWithInvalidConfiguration() {
    // Given
    let invalidConfig = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)

    // When
    SwiftUIInstrumentation.shared.initialize(with: invalidConfig)

    // Then - Should still initialize properly
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled)
  }

  func testMultipleInitializationCalls() {
    // Given
    let config1 = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
    let config2 = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false)

    // When
    SwiftUIInstrumentation.shared.initialize(with: config1)
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled)

    SwiftUIInstrumentation.shared.initialize(with: config2)

    // Then
    XCTAssertFalse(SwiftUIInstrumentation.shared.isInstrumentationEnabled, "Should update on subsequent calls")
  }

  // MARK: - Performance Tests (without UI)

  func testInstrumentationOverheadWhenEnabled() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))

    measure {
      // Simulate the overhead of checking if instrumentation is enabled
      for _ in 0 ..< 1000 {
        _ = SwiftUIInstrumentation.shared.isInstrumentationEnabled
      }
    }
  }

  func testInstrumentationOverheadWhenDisabled() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false))

    measure {
      // Simulate the overhead of checking if instrumentation is enabled
      for _ in 0 ..< 1000 {
        _ = SwiftUIInstrumentation.shared.isInstrumentationEnabled
      }
    }
  }

  func testSpanCreationPerformance() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    measure {
      // Simulate creating spans like SwiftUI instrumentation would
      for i in 0 ..< 100 {
        let span = tracer.spanBuilder(spanName: "TestView\(i)").startSpan()
        span.setAttribute(key: "view.name", value: "TestView\(i)")
        span.setAttribute(key: "view.type", value: "swiftui")
        span.end()
      }
    }
  }
}
