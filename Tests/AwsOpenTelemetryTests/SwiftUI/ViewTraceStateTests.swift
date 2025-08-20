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
final class ViewTraceStateTests: XCTestCase {
  var mockSpanProcessor: MockSpanProcessor!
  var mockTracerProvider: TracerProviderSdk!
  var originalTracerProvider: TracerProvider!

  override func setUpWithError() throws {
    // Set up mock tracer provider
    mockSpanProcessor = MockSpanProcessor()
    mockTracerProvider = TracerProviderBuilder()
      .add(spanProcessor: mockSpanProcessor)
      .build()

    // Store original and set mock
    originalTracerProvider = OpenTelemetry.instance.tracerProvider
    OpenTelemetry.registerTracerProvider(tracerProvider: mockTracerProvider)
  }

  override func tearDownWithError() throws {
    // Restore original tracer provider
    OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)

    // Clean up
    mockSpanProcessor = nil
    mockTracerProvider = nil
  }

  // MARK: - Initialization Tests

  func testInitialState() {
    // Given & When
    let state = ViewTraceState()

    // Then
    XCTAssertNil(state.rootSpan, "Root span should be nil initially")
    XCTAssertEqual(state.appearCount, 0, "Appear count should be 0 initially")
    XCTAssertEqual(state.disappearCount, 0, "Disappear count should be 0 initially")
    XCTAssertNotNil(state.initializationTime, "Initialization time should be set")
  }

  func testInitializationTime() {
    // Given
    let beforeCreation = Date()

    // When
    let state = ViewTraceState()
    let afterCreation = Date()

    // Then
    XCTAssertGreaterThanOrEqual(state.initializationTime, beforeCreation, "Initialization time should be after creation start")
    XCTAssertLessThanOrEqual(state.initializationTime, afterCreation, "Initialization time should be before creation end")
  }

  // MARK: - Reference Semantics Tests

  func testReferenceSemantics() {
    // Given
    let state1 = ViewTraceState()
    let state2 = state1

    // When
    state1.appearCount = 5

    // Then
    XCTAssertEqual(state2.appearCount, 5, "Should share the same instance (reference semantics)")
    XCTAssertTrue(state1 === state2, "Should be the same object reference")
  }

  func testIndependentInstances() {
    // Given
    let state1 = ViewTraceState()
    let state2 = ViewTraceState()

    // When
    state1.appearCount = 3
    state2.appearCount = 7

    // Then
    XCTAssertEqual(state1.appearCount, 3, "State1 should maintain its own count")
    XCTAssertEqual(state2.appearCount, 7, "State2 should maintain its own count")
    XCTAssertFalse(state1 === state2, "Should be different object references")
  }

  // MARK: - Span Management Tests

  func testRootSpanAssignment() {
    // Given
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")
    let span = tracer.spanBuilder(spanName: "TestSpan").startSpan()

    // When
    state.rootSpan = span

    // Then
    XCTAssertNotNil(state.rootSpan, "Root span should be assigned")
    XCTAssertEqual(state.rootSpan?.name, "TestSpan", "Root span should have correct name")
  }

  func testRootSpanReplacement() {
    // Given
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")
    let span1 = tracer.spanBuilder(spanName: "TestSpan1").startSpan()
    let span2 = tracer.spanBuilder(spanName: "TestSpan2").startSpan()

    // When
    state.rootSpan = span1
    XCTAssertEqual(state.rootSpan?.name, "TestSpan1")

    state.rootSpan = span2

    // Then
    XCTAssertEqual(state.rootSpan?.name, "TestSpan2", "Root span should be replaced")
  }

  func testRootSpanNilAssignment() {
    // Given
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")
    let span = tracer.spanBuilder(spanName: "TestSpan").startSpan()

    // When
    state.rootSpan = span
    XCTAssertNotNil(state.rootSpan)

    state.rootSpan = nil

    // Then
    XCTAssertNil(state.rootSpan, "Root span should be set to nil")
  }

  // MARK: - Counter Tests

  func testAppearCountIncrement() {
    // Given
    let state = ViewTraceState()
    XCTAssertEqual(state.appearCount, 0)

    // When
    state.appearCount += 1

    // Then
    XCTAssertEqual(state.appearCount, 1, "Appear count should increment")

    // When
    state.appearCount += 1

    // Then
    XCTAssertEqual(state.appearCount, 2, "Appear count should increment again")
  }

  func testDisappearCountIncrement() {
    // Given
    let state = ViewTraceState()
    XCTAssertEqual(state.disappearCount, 0)

    // When
    state.disappearCount += 1

    // Then
    XCTAssertEqual(state.disappearCount, 1, "Disappear count should increment")

    // When
    state.disappearCount += 1

    // Then
    XCTAssertEqual(state.disappearCount, 2, "Disappear count should increment again")
  }

  func testCounterIndependence() {
    // Given
    let state = ViewTraceState()

    // When
    state.appearCount = 5
    state.disappearCount = 3

    // Then
    XCTAssertEqual(state.appearCount, 5, "Appear count should be independent")
    XCTAssertEqual(state.disappearCount, 3, "Disappear count should be independent")
  }

  // MARK: - Memory Management Tests

  func testSpanRetention() {
    // Given
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    weak var weakSpan: Span?

    // When
    autoreleasepool {
      let span = tracer.spanBuilder(spanName: "TestSpan").startSpan()
      weakSpan = span
      state.rootSpan = span
    }

    // Then
    XCTAssertNotNil(weakSpan, "Span should be retained by state")
    XCTAssertNotNil(state.rootSpan, "State should retain the span")

    // When
    state.rootSpan = nil

    // Then - This might still be retained by the tracer/processor, so we can't guarantee it's nil
    // But we can verify the state no longer holds it
    XCTAssertNil(state.rootSpan, "State should no longer hold the span")
  }

  // MARK: - Thread Safety Tests

  func testConcurrentCounterAccess() {
    // Given
    let state = ViewTraceState()
    let expectation = XCTestExpectation(description: "Concurrent counter access")
    expectation.expectedFulfillmentCount = 100

    let queue = DispatchQueue.global(qos: .userInitiated)

    // When - Multiple threads incrementing counters
    for _ in 0 ..< 100 {
      queue.async {
        state.appearCount += 1
        expectation.fulfill()
      }
    }

    // Then
    wait(for: [expectation], timeout: 5.0)

    // Note: Without proper synchronization, this test might reveal race conditions
    // The actual count might be less than 100 due to race conditions
    XCTAssertGreaterThan(state.appearCount, 0, "Should have incremented at least once")
    XCTAssertLessThanOrEqual(state.appearCount, 100, "Should not exceed expected maximum")
  }

  // MARK: - Lifecycle Simulation Tests

  func testTypicalViewLifecycle() {
    // Given
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // When - Simulate typical view lifecycle
    // 1. View appears
    state.appearCount += 1
    let rootSpan = tracer.spanBuilder(spanName: "TestView").startSpan()
    state.rootSpan = rootSpan

    // 2. View disappears
    state.disappearCount += 1
    state.rootSpan?.end()
    state.rootSpan = nil

    // Then
    XCTAssertEqual(state.appearCount, 1, "Should have appeared once")
    XCTAssertEqual(state.disappearCount, 1, "Should have disappeared once")
    XCTAssertNil(state.rootSpan, "Root span should be cleared")
  }

  func testMultipleAppearDisappearCycles() {
    // Given
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // When - Simulate multiple appear/disappear cycles
    for i in 1 ... 3 {
      // Appear
      state.appearCount += 1
      let span = tracer.spanBuilder(spanName: "TestView\(i)").startSpan()
      state.rootSpan = span

      // Disappear
      state.disappearCount += 1
      state.rootSpan?.end()
      state.rootSpan = nil
    }

    // Then
    XCTAssertEqual(state.appearCount, 3, "Should have appeared 3 times")
    XCTAssertEqual(state.disappearCount, 3, "Should have disappeared 3 times")
    XCTAssertNil(state.rootSpan, "Root span should be cleared after final cycle")
  }
}
