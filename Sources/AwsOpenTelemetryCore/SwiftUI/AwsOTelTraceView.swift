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
  private static var tracer: Tracer {
    OpenTelemetry.instance.tracerProvider.get(
      instrumentationName: AwsInstrumentationScopes.SWIFTUI_VIEW
    )
  }

  private static var logger: Logger {
    OpenTelemetry.instance.loggerProvider.get(
      instrumentationScopeName: AwsInstrumentationScopes.SWIFTUI_VIEW
    )
  }

  @State private var initializationTime = Date()
  @State private var hasAppeared = false

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
  }

  /// Convenience initializer with string attributes (auto-converted to AttributeValue).
  public init(_ screenName: String,
              attributes: [String: String],
              @SwiftUI.ViewBuilder content: @escaping () -> Content) {
    self.screenName = screenName
    self.attributes = attributes.mapValues { AttributeValue.string($0) }
    self.content = content
  }

  public var body: some SwiftUI.View {
    // Check if SwiftUI instrumentation is enabled via the configuration
    guard isViewInstrumentationEnabled else {
      return content()
        .onAppear() // placeholder to satisfy return type
        .onDisappear()
    }

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

    let now = Date()

    // Record TimeToFirstAppear span
    if !hasAppeared {
      hasAppeared = true
      let span = Self.tracer.spanBuilder(spanName: AwsTimeToFirstAppear.name)
        .setAttribute(key: AwsTimeToFirstAppear.screenName, value: screenName)
        .setAttribute(key: AwsTimeToFirstAppear.type, value: AwsViewType.swiftui.rawValue)
        .setStartTime(time: initializationTime)
        .startSpan()

      for (key, value) in attributes {
        span.setAttribute(key: key, value: value)
      }

      span.end(time: now)
    }

    // Record ViewDidAppear log event
    AwsScreenManagerProvider.getInstance().logViewDidAppear(screen: screenName, type: .swiftui, timestamp: now, additionalAttributes: attributes)
  }

  func handleViewDisappear() {
    // noop
  }
}
