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
final class AwsOpenTelemetryTraceViewPerformanceTests: XCTestCase {
  var mockSpanProcessor: MockSpanProcessor!
  var mockTracerProvider: TracerProviderSdk!
  var originalTracerProvider: TracerProvider!

  override func setUpWithError() throws {
    // Create a fresh mock span processor for each test
    mockSpanProcessor = MockSpanProcessor()
    print("Created fresh MockSpanProcessor with \(mockSpanProcessor.getEndedSpans().count) spans")

    mockTracerProvider = TracerProviderBuilder()
      .add(spanProcessor: mockSpanProcessor)
      .build()

    // Store original and set mock
    originalTracerProvider = OpenTelemetry.instance.tracerProvider
    OpenTelemetry.registerTracerProvider(tracerProvider: mockTracerProvider)

    // Reset SwiftUI instrumentation
    SwiftUIInstrumentation.shared.reset()
  }

  override func tearDownWithError() throws {
    // Restore original tracer provider
    OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)

    // Clean up
    mockSpanProcessor?.reset()
    mockSpanProcessor = nil
    mockTracerProvider = nil
    SwiftUIInstrumentation.shared.reset()
  }

  // MARK: - Core Performance Tests

  func testInstrumentationCheckPerformanceEnabled() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))

    // Manual performance measurement to avoid baseline warnings
    let startTime = CFAbsoluteTimeGetCurrent()

    // Simulate the performance impact of checking instrumentation status
    // This is what happens in every SwiftUI view body evaluation
    for _ in 0 ..< 10000 {
      _ = SwiftUIInstrumentation.shared.isInstrumentationEnabled
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    print("Instrumentation check (enabled) took \(duration) seconds for 10,000 operations")

    // Verify it's reasonably fast (should be very quick)
    XCTAssertLessThan(duration, 0.1, "10,000 instrumentation checks should take less than 0.1 seconds")
  }

  func testInstrumentationCheckPerformanceDisabled() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false))

    // Manual performance measurement to avoid baseline warnings
    let startTime = CFAbsoluteTimeGetCurrent()

    // Simulate the performance impact of checking instrumentation status
    for _ in 0 ..< 10000 {
      _ = SwiftUIInstrumentation.shared.isInstrumentationEnabled
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    print("Instrumentation check (disabled) took \(duration) seconds for 10,000 operations")

    // Verify it's reasonably fast (should be very quick)
    XCTAssertLessThan(duration, 0.1, "10,000 instrumentation checks should take less than 0.1 seconds")
  }

  // MARK: - Span Creation Performance Tests

  func testSimpleSpanCreationPerformanceEnabled() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // Manual performance measurement to avoid baseline warnings
    let startTime = CFAbsoluteTimeGetCurrent()

    // Simulate creating simple spans like SwiftUI views would
    for i in 0 ..< 100 {
      let span = tracer.spanBuilder(spanName: "TestView\(i)").startSpan()
      span.setAttribute(key: "view.name", value: "TestView\(i)")
      span.setAttribute(key: "view.type", value: "swiftui")
      span.end()
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    print("Simple span creation took \(duration) seconds for 100 spans")

    // Verify it's reasonably fast
    XCTAssertLessThan(duration, 1.0, "Creating 100 simple spans should take less than 1 second")
  }

  func testComplexSpanCreationPerformanceEnabled() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // Manual performance measurement to avoid baseline warnings
    let startTime = CFAbsoluteTimeGetCurrent()

    // Simulate creating complex spans with multiple attributes
    for i in 0 ..< 50 {
      let rootSpan = tracer.spanBuilder(spanName: "ComplexView\(i)").startSpan()
      rootSpan.setAttribute(key: "view.name", value: "ComplexView\(i)")
      rootSpan.setAttribute(key: "view.type", value: "swiftui")
      rootSpan.setAttribute(key: "screen_type", value: "complex")
      rootSpan.setAttribute(key: "user_id", value: "user_\(i)")
      rootSpan.setAttribute(key: "is_premium", value: i % 2 == 0)
      rootSpan.setAttribute(key: "item_count", value: i * 10)

      // Create child spans
      let onAppearSpan = tracer.spanBuilder(spanName: "ComplexView\(i).onAppear")
        .setParent(rootSpan)
        .startSpan()
      onAppearSpan.setAttribute(key: "view.lifecycle", value: "onAppear")
      onAppearSpan.end()

      let bodySpan = tracer.spanBuilder(spanName: "ComplexView\(i).body")
        .setParent(rootSpan)
        .startSpan()
      bodySpan.setAttribute(key: "view.lifecycle", value: "body")
      bodySpan.setAttribute(key: "view.body.evaluation", value: 1)
      bodySpan.end()

      rootSpan.end()
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    print("Complex span creation took \(duration) seconds for 50 complex spans (150 total spans)")

    // Verify it's reasonably fast
    XCTAssertLessThan(duration, 2.0, "Creating 50 complex spans should take less than 2 seconds")
  }

  // MARK: - ViewTraceState Performance Tests

  func testViewTraceStatePerformance() {
    // Manual performance measurement to avoid baseline warnings
    let startTime = CFAbsoluteTimeGetCurrent()

    // Simulate creating and managing ViewTraceState objects
    for _ in 0 ..< 1000 {
      let state = ViewTraceState()
      state.appearCount += 1
      state.disappearCount += 1
      _ = state.initializationTime
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    print("ViewTraceState creation took \(duration) seconds for 1000 objects")

    // Verify it's reasonably fast
    XCTAssertLessThan(duration, 0.5, "Creating 1000 ViewTraceState objects should take less than 0.5 seconds")
  }

  func testViewTraceStateWithSpansPerformance() {
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // Manual performance measurement to avoid baseline warnings
    let startTime = CFAbsoluteTimeGetCurrent()

    // Simulate ViewTraceState lifecycle with spans
    for i in 0 ..< 100 {
      let state = ViewTraceState()

      // Simulate view appearing
      state.appearCount += 1
      let span = tracer.spanBuilder(spanName: "TestView\(i)").startSpan()
      state.rootSpan = span

      // Simulate view disappearing
      state.disappearCount += 1
      span.end()
      state.rootSpan = nil
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    print("ViewTraceState with spans took \(duration) seconds for 100 objects")

    // Verify it's reasonably fast
    XCTAssertLessThan(duration, 1.0, "Creating 100 ViewTraceState objects with spans should take less than 1 second")
  }

  // MARK: - Memory Performance Tests

  func testMemoryUsageWithManySpans() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))

    // Create a completely isolated span processor and tracer provider for this test
    let isolatedSpanProcessor = MockSpanProcessor()
    let isolatedTracerProvider = TracerProviderBuilder()
      .add(spanProcessor: isolatedSpanProcessor)
      .build()

    let tracer = isolatedTracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // Test memory usage by creating many spans (just once, not in measure block)
    let startTime = CFAbsoluteTimeGetCurrent()

    // Create many spans to test memory usage
    for i in 0 ..< 1000 {
      let span = tracer.spanBuilder(spanName: "MemoryTestView\(i)").startSpan()
      span.setAttribute(key: "view.name", value: "MemoryTestView\(i)")
      span.setAttribute(key: "iteration", value: i)
      span.end()
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    // Verify spans were created (should be exactly 1000)
    let spans = isolatedSpanProcessor.getEndedSpans()
    XCTAssertEqual(spans.count, 1000, "Should create exactly 1000 spans, but got \(spans.count)")

    // Report the timing manually
    print("Memory test completed in \(duration) seconds for 1000 spans")

    // Ensure the test runs reasonably fast (less than 1 second for 1000 spans)
    XCTAssertLessThan(duration, 1.0, "Creating 1000 spans should take less than 1 second")
  }

  // MARK: - Concurrent Performance Tests

  func testConcurrentInstrumentationAccess() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))

    // Manual performance measurement to avoid baseline warnings
    let startTime = CFAbsoluteTimeGetCurrent()

    let group = DispatchGroup()
    let queue = DispatchQueue.global(qos: .userInitiated)

    // Simulate multiple threads checking instrumentation status
    for _ in 0 ..< 10 {
      group.enter()
      queue.async {
        for _ in 0 ..< 1000 {
          _ = SwiftUIInstrumentation.shared.isInstrumentationEnabled
        }
        group.leave()
      }
    }

    group.wait()

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    print("Concurrent instrumentation access took \(duration) seconds for 10 threads × 1000 operations")

    // Verify it's reasonably fast and doesn't deadlock
    XCTAssertLessThan(duration, 2.0, "Concurrent access should take less than 2 seconds")
  }

  func testConcurrentSpanCreation() {
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    // Manual performance measurement to avoid baseline warnings
    let startTime = CFAbsoluteTimeGetCurrent()

    let group = DispatchGroup()
    let queue = DispatchQueue.global(qos: .userInitiated)

    // Simulate multiple threads creating spans
    for threadId in 0 ..< 5 {
      group.enter()
      queue.async {
        for i in 0 ..< 50 {
          let span = tracer.spanBuilder(spanName: "ConcurrentView\(threadId)_\(i)").startSpan()
          span.setAttribute(key: "thread_id", value: threadId)
          span.setAttribute(key: "iteration", value: i)
          span.end()
        }
        group.leave()
      }
    }

    group.wait()

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    print("Concurrent span creation took \(duration) seconds for 5 threads × 50 spans")

    // Verify it's reasonably fast and thread-safe
    XCTAssertLessThan(duration, 2.0, "Concurrent span creation should take less than 2 seconds")
  }

  // MARK: - Comparison Tests

  func testOverheadComparisonEnabledVsDisabled() {
    // Test enabled performance
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true))

    let enabledTime = measureTime {
      for _ in 0 ..< 5000 {
        _ = SwiftUIInstrumentation.shared.isInstrumentationEnabled
      }
    }

    // Test disabled performance
    SwiftUIInstrumentation.shared.initialize(with: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false))

    let disabledTime = measureTime {
      for _ in 0 ..< 5000 {
        _ = SwiftUIInstrumentation.shared.isInstrumentationEnabled
      }
    }

    // Both should be very fast, but disabled might be slightly faster
    XCTAssertLessThan(enabledTime, 0.1, "Enabled instrumentation check should be very fast")
    XCTAssertLessThan(disabledTime, 0.1, "Disabled instrumentation check should be very fast")

    print("Enabled time: \(enabledTime)s, Disabled time: \(disabledTime)s")
  }

  // MARK: - Helper Methods

  private func measureTime(operation: () -> some Any) -> TimeInterval {
    let startTime = CFAbsoluteTimeGetCurrent()
    _ = operation()
    let endTime = CFAbsoluteTimeGetCurrent()
    return endTime - startTime
  }
}
