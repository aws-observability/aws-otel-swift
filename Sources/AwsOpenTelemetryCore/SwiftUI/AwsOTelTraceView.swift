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

import SwiftUI
import OpenTelemetryApi
import OpenTelemetrySdk

/// SwiftUI wrapper view that instruments view lifecycle tracing.
/// Creates spans for root view, body evaluations, onAppear/onDisappear events, and timeToFirstAppear.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public struct AwsOTelTraceView<Content: SwiftUI.View>: SwiftUI.View {
  let instrumentationName = AwsInstrumentationScopes.SWIFTUI_VIEW
  let instrumentationVersion = AwsOpenTelemetryAgent.version
  let tracer: Tracer
  let logger: Logger

  @State private var state = ViewTraceState()
  @State private var bodyEvaluationCount = 0

  private let content: () -> Content
  private let screenName: String
  private let attributes: [String: AttributeValue]

  private var isViewInstrumentationEnabled: Bool {
    AwsOpenTelemetryAgent.shared.configuration?.telemetry?.view?.enabled == true
  }

  /// Creates a traced view wrapper.
  /// - Parameters:
  ///   - screenName: Stable identifier for trace dashboards
  ///   - attributes: Optional span metadata
  ///   - content: View content to wrap
  public init(_ screenName: String,
              attributes: [String: AttributeValue] = [:],
              @SwiftUI.ViewBuilder content: @escaping () -> Content) {
    self.screenName = screenName
    self.attributes = attributes
    self.content = content
    tracer = OpenTelemetry.instance.tracerProvider.get(
      instrumentationName: instrumentationName,
      instrumentationVersion: instrumentationVersion
    )
    logger = OpenTelemetry.instance.loggerProvider.get(
      instrumentationScopeName: instrumentationName
    )
  }

  /// Convenience initializer with string attributes (auto-converted to AttributeValue).
  public init(_ screenName: String,
              attributes: [String: String],
              @SwiftUI.ViewBuilder content: @escaping () -> Content) {
    self.screenName = screenName
    self.attributes = attributes.mapValues { AttributeValue.string($0) }
    self.content = content

    tracer = OpenTelemetry.instance.tracerProvider.get(
      instrumentationName: instrumentationName,
      instrumentationVersion: instrumentationVersion
    )
    logger = OpenTelemetry.instance.loggerProvider.get(
      instrumentationScopeName: instrumentationName
    )
  }

  public var body: some SwiftUI.View {
    // Check if SwiftUI instrumentation is enabled via the configuration
    guard isViewInstrumentationEnabled else {
      return content()
        .onAppear() // placeholder to satisfy return type
        .onDisappear()
    }

    // Track body evaluation
    bodyEvaluationCount += 1

    return content()
      .onAppear {
        handleViewAppear()
      }
      .onDisappear {
        handleViewDisappear()
      }
  }

  func handleViewAppear() {
    // Check if SwiftUI instrumentation is enabled
    guard isViewInstrumentationEnabled else {
      return
    }

    let appearTime = Date()

    // Create time to first draw span on first appear
    if state.appearCount == 0 {
      let timeToFirstAppearSpan = tracer.spanBuilder(spanName: AwsViewConstants.TimeToFirstAppear)
        .setSpanKind(spanKind: .client)
        .setStartTime(time: state.initializationTime)
        .startSpan()

      timeToFirstAppearSpan.setAttribute(key: AwsViewConstants.attributeScreenName, value: screenName)
      timeToFirstAppearSpan.setAttribute(key: AwsViewConstants.attributeViewLifecycle, value: AwsViewConstants.TimeToFirstAppear)
      timeToFirstAppearSpan.end(time: appearTime)
    }

    state.appearCount += 1

    // Create .onAppear
    let onAppearSpan = tracer.spanBuilder(spanName: AwsViewConstants.spanNameOnAppear)
      .setSpanKind(spanKind: .client)
      .setStartTime(time: appearTime)
      .startSpan()

    onAppearSpan.setAttribute(key: AwsViewConstants.attributeScreenName, value: screenName)
    onAppearSpan.setAttribute(key: AwsViewConstants.attributeViewLifecycle, value: AwsViewConstants.valueOnAppear)
    onAppearSpan.setAttribute(key: AwsViewConstants.attributeViewAppearCount, value: state.appearCount)
    onAppearSpan.end()

    // Start view.duration span to track visibility time
    let viewDurationSpan = tracer.spanBuilder(spanName: AwsViewConstants.spanNameTimeOnScreen)
      .setSpanKind(spanKind: .client)
      .setStartTime(time: appearTime)
      .startSpan()

    viewDurationSpan.setAttribute(key: AwsViewConstants.attributeScreenName, value: screenName)
    viewDurationSpan.setAttribute(key: AwsViewConstants.attributeViewType, value: AwsViewConstants.valueSwiftUI)

    state.durationSpan = viewDurationSpan
  }

  func handleViewDisappear() {
    // Check if SwiftUI instrumentation is enabled
    guard isViewInstrumentationEnabled else {
      return
    }

    let disappearTime = Date()

    // Create .onDisappear log
    logger.logRecordBuilder()
      .setEventName("ViewDidDisappear")
      .setTimestamp(disappearTime)
      .setAttributes([
        AwsViewConstants.attributeScreenName: AttributeValue.string(screenName),
        AwsViewConstants.attributeViewLifecycle: AttributeValue.string(AwsViewConstants.valueOnDisappear),
        AwsViewConstants.attributeViewDisappearCount: AttributeValue.int(state.disappearCount + 1)
      ])
      .emit()

    // End TimeOnScreen span when view disappears
    if let viewDurationSpan = state.durationSpan {
      viewDurationSpan.end(time: disappearTime)
      state.durationSpan = nil
    }

    state.disappearCount += 1
  }
}
