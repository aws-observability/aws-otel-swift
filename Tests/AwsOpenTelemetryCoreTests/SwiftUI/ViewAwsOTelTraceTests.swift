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

  func testBasicTraceExtension() {
    XCTAssertNoThrow {
      let view = Text("Hello World")
      let tracedView = view.awsOpenTelemetryTrace("HomeView")
      XCTAssertNotNil(tracedView)
    }
  }

  func testTraceExtensionWithStringAttributes() {
    XCTAssertNoThrow {
      let view = Text("Hello World")
      let tracedView = view.awsOpenTelemetryTrace(
        "HomeView",
        attributes: ["screen_type": "home"]
      )
      XCTAssertNotNil(tracedView)
    }
  }

  func testTraceExtensionWithAttributeValues() {
    XCTAssertNoThrow {
      let view = Text("Hello World")
      let tracedView = view.awsOpenTelemetryTrace(
        "HomeView",
        attributes: ["screen_type": .string("home"), "count": .int(1)]
      )
      XCTAssertNotNil(tracedView)
    }
  }

  func testBody() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let view = Text("Hello World")
    let tracedView = view.awsOpenTelemetryTrace("HomeView")

    _ = tracedView.body

    XCTAssertNotNil(tracedView)
  }

  func testHandleViewAppear() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let view = Text("Hello World")
    let tracedView = view.awsOpenTelemetryTrace("HomeView")

    // Access the underlying AwsOTelTraceView to call handleViewAppear
    if let traceView = tracedView as? AwsOTelTraceView<Text> {
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
      XCTAssertEqual(timeToFirstAppearSpan?.attributes[AwsViewConstants.attributeScreenName]?.description, "HomeView")

      let onAppearSpan = spans.first { $0.name == AwsViewConstants.spanNameOnAppear }
      XCTAssertNotNil(onAppearSpan)
      XCTAssertEqual(onAppearSpan?.attributes[AwsViewConstants.attributeScreenName]?.description, "HomeView")
    }
  }

  func testHandleViewDisappear() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: TelemetryConfig.builder().with(view: TelemetryFeature(enabled: true)).build()
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    let view = Text("Hello World")
    let tracedView = view.awsOpenTelemetryTrace("HomeView")

    // Access the underlying AwsOTelTraceView to call methods
    if let traceView = tracedView as? AwsOTelTraceView<Text> {
      traceView.handleViewAppear()
      traceView.handleViewDisappear()

      let spans = mockSpanProcessor.getEndedSpans()
      XCTAssertEqual(spans.count, 5) // TimeToFirstAppear + onAppear + onDisappear + root + view.duration
      XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.TimeToFirstAppear })
      XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameOnAppear })
      XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameOnDisappear })
      XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameView })
      XCTAssertTrue(spans.contains { $0.name == AwsViewConstants.spanNameViewDuration })

      // Verify screen.name attribute is set on all spans
      let expectedSpanNames = [AwsViewConstants.TimeToFirstAppear, AwsViewConstants.spanNameOnAppear, AwsViewConstants.spanNameOnDisappear, AwsViewConstants.spanNameView, AwsViewConstants.spanNameViewDuration]
      let allSpans = spans.filter { expectedSpanNames.contains($0.name) }
      for span in allSpans {
        XCTAssertEqual(span.attributes[AwsViewConstants.attributeScreenName]?.description, "HomeView", "Span \(span.name) should have screen.name attribute")
      }
    }
  }
}
