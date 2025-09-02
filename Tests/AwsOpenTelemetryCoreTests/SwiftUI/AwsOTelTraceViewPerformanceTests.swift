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
final class AwsOTelTraceViewPerformanceTests: XCTestCase {
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

  func testSpanCreationPerformance() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0.0")

    let startTime = CFAbsoluteTimeGetCurrent()
    for i in 0 ..< 100 {
      let span = tracer.spanBuilder(spanName: "TestView\(i)").startSpan()
      span.setAttribute(key: "view.name", value: "TestView\(i)")
      span.setAttribute(key: "view.type", value: "swiftui")
      span.end()
    }
    let duration = CFAbsoluteTimeGetCurrent() - startTime

    XCTAssertLessThan(duration, 1.0, "Creating 100 spans should take less than 1 second")
  }
}
