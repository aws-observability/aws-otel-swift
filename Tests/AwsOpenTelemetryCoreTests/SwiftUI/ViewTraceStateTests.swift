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
    mockSpanProcessor = MockSpanProcessor()
    mockTracerProvider = TracerProviderBuilder()
      .add(spanProcessor: mockSpanProcessor)
      .build()

    originalTracerProvider = OpenTelemetry.instance.tracerProvider
    OpenTelemetry.registerTracerProvider(tracerProvider: mockTracerProvider)
  }

  override func tearDownWithError() throws {
    OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
    mockSpanProcessor = nil
    mockTracerProvider = nil
  }

  func testInitialState() {
    let state = ViewTraceState()

    XCTAssertNil(state.rootSpan)
    XCTAssertEqual(state.appearCount, 0)
    XCTAssertEqual(state.disappearCount, 0)
    XCTAssertNotNil(state.initializationTime)
  }

  func testSpanManagement() {
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")
    let span = tracer.spanBuilder(spanName: "TestSpan").startSpan()

    state.rootSpan = span
    XCTAssertNotNil(state.rootSpan)
    XCTAssertEqual(state.rootSpan?.name, "TestSpan")

    state.rootSpan = nil
    XCTAssertNil(state.rootSpan)
  }

  func testCounterIncrement() {
    let state = ViewTraceState()

    XCTAssertEqual(state.appearCount, 0)
    XCTAssertEqual(state.disappearCount, 0)

    state.appearCount += 1
    state.disappearCount += 1
    XCTAssertEqual(state.appearCount, 1)
    XCTAssertEqual(state.disappearCount, 1)

    for i in 2 ... 5 {
      state.appearCount += 1
      XCTAssertEqual(state.appearCount, i)
    }

    state.disappearCount += 10
    XCTAssertEqual(state.disappearCount, 11)

    state.appearCount = 100
    XCTAssertEqual(state.appearCount, 100)
    XCTAssertEqual(state.disappearCount, 11)
  }

  func testViewLifecycle() {
    let state = ViewTraceState()
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    XCTAssertEqual(state.appearCount, 0)
    XCTAssertNil(state.rootSpan)

    state.appearCount += 1
    let rootSpan = tracer.spanBuilder(spanName: "TestView").startSpan()
    state.rootSpan = rootSpan
    XCTAssertEqual(state.appearCount, 1)
    XCTAssertEqual(state.rootSpan?.name, "TestView")

    for i in 2 ... 3 {
      state.appearCount += 1
      let span = tracer.spanBuilder(spanName: "View\(i)").startSpan()
      state.rootSpan = span
      XCTAssertEqual(state.rootSpan?.name, "View\(i)")
    }

    state.disappearCount += 1
    state.rootSpan?.end()
    state.rootSpan = nil
    XCTAssertEqual(state.appearCount, 3)
    XCTAssertEqual(state.disappearCount, 1)
    XCTAssertNil(state.rootSpan)
  }
}
