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
final class ViewAwsOTelTraceTests: XCTestCase {
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

  func testHandleViewAppear() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: AwsTelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let view = Text("Hello World")
    let tracedView = view.awsOpenTelemetryTrace("HomeView")

    // Access the underlying AwsOTelTraceView to call handleViewAppear
    if let traceView = tracedView as? AwsOTelTraceView<Text> {
      traceView.handleViewAppear()

      let spans = mockSpanProcessor.getEndedSpans()
      _ = mockSpanProcessor.getStartedSpans()
      XCTAssertGreaterThan(spans.count, 0)

      // Check if any spans were created with screen name
      if let firstSpan = spans.first {
        if let screenName = firstSpan.attributes[AwsViewSemConv.screenName] {
          XCTAssertEqual(screenName.description, "HomeView")
        }
      }
    }
  }

  func testTraceViewAttributesAppliedToSpans() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: AwsTelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let view = Text("Hello World")
    let tracedView = view.awsOpenTelemetryTrace("TestView")

    if let traceView = tracedView as? AwsOTelTraceView<Text> {
      traceView.handleViewAppear()

      let spans = mockSpanProcessor.getEndedSpans()
      XCTAssertGreaterThan(spans.count, 0)

      // Verify spans have the screen.name attribute
      for span in spans {
        XCTAssertEqual(span.attributes[AwsViewSemConv.screenName]?.description, "TestView")
      }
    }
  }
}
