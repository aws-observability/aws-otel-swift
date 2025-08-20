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

/// A SwiftUI wrapper view that instruments performance tracing for view load times.
///
/// Use `AwsOpenTelemetryTraceView` to automatically record view lifecycle events
/// with the following span hierarchy:
///
/// ## Span Structure
///
/// ```
/// {viewName} (root span: init → onDisappear)
/// ├── {viewName}.body (child span - can be multiple)
/// ├── {viewName}.onAppear (child span)
/// └── {viewName}.onDisappear (child span)
/// ```
///
/// - **Root span**: Captures the entire view lifecycle from initialization to disappearance
/// - **Body spans**: Created each time SwiftUI re-evaluates the view's body
/// - **Lifecycle spans**: Track onAppear and onDisappear events
///
/// ## Configuration
///
/// Instrumentation can be globally enabled/disabled:
/// ```swift
/// // Disable all SwiftUI tracing (zero overhead)
/// AwsOpenTelemetryTelemetryConfig.shared.disableSwiftUIInstrumentation()
/// ```
///
/// ## Example Usage
///
/// ```swift
/// AwsOpenTelemetryTraceView("HomeScreen") {
///     HomeView()
/// }
///
/// AwsOpenTelemetryTraceView("ProfileDetail",
///                          attributes: ["user_id": "12345"]) {
///     ProfileDetailView(user: user)
/// }
/// ```
///
/// ## Performance Considerations
///
/// - Root span tracks the complete view lifecycle from initialization to disappearance
/// - Body spans capture each SwiftUI body re-evaluation (useful for performance analysis)
/// - Uses reference semantics (`ViewTraceState` class) to prevent SwiftUI re-renders
/// - Automatically handles span cleanup on view disappearance
/// - Minimal overhead when OpenTelemetry is not configured
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public struct AwsOpenTelemetryTraceView<Content: View>: View {
  let instrumentationName = "aws-opentelemetry-swift"
  let instrumentationVersion = "1.0.0"

  @State private var state = ViewTraceState()
  @State private var bodyEvaluationCount = 0

  private let content: () -> Content
  private let viewName: String
  private let attributes: [String: AttributeValue]

  /// Creates a new `AwsOpenTelemetryTraceView` that wraps the given content for tracing.
  ///
  /// - Parameters:
  ///   - viewName: The stable identifier used in trace dashboards (e.g., screen or component name).
  ///   - attributes: Optional metadata to associate with all spans created by this view.
  ///   - content: A closure returning the view content to wrap.
  public init(_ viewName: String,
              attributes: [String: AttributeValue] = [:],
              @SwiftUI.ViewBuilder content: @escaping () -> Content) {
    self.viewName = viewName
    self.attributes = attributes
    self.content = content
  }

  /// Convenience initializer with string attributes
  ///
  /// String attributes are automatically converted to `AttributeValue.string()`.
  ///
  /// - Parameters:
  ///   - viewName: The stable identifier used in trace dashboards
  ///   - attributes: Optional string metadata to associate with spans
  ///   - content: A closure returning the view content to wrap
  public init(_ viewName: String,
              attributes: [String: String] = [:],
              @SwiftUI.ViewBuilder content: @escaping () -> Content) {
    self.viewName = viewName
    self.attributes = attributes.mapValues { AttributeValue.string($0) }
    self.content = content
  }

  public var body: some View {
    // Check if SwiftUI instrumentation is enabled via the singleton
    guard SwiftUIInstrumentation.shared.isInstrumentationEnabled else {
      return content()
        .onAppear() // placeholder to satisfy return type
        .onDisappear()
    }

    // Track body evaluation
    let bodyStartTime = Date()
    bodyEvaluationCount += 1

    // Create body span as child of root span
    if let rootSpan = state.rootSpan {
      let tracer = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: instrumentationName,
        instrumentationVersion: instrumentationVersion
      )

      let bodySpan = tracer.spanBuilder(spanName: "\(viewName).body")
        .setParent(rootSpan)
        .setSpanKind(spanKind: .client)
        .setStartTime(time: bodyStartTime)
        .startSpan()

      bodySpan.setAttribute(key: "view.body.evaluation", value: bodyEvaluationCount)
      bodySpan.setAttribute(key: "view.lifecycle", value: "body")

      // End body span immediately since body evaluation is complete
      bodySpan.end()
    }

    return content()
      .onAppear {
        handleViewAppear()
      }
      .onDisappear {
        handleViewDisappear()
      }
  }

  // MARK: - Private Methods

  private func handleViewAppear() {
    // Check if SwiftUI instrumentation is enabled
    guard SwiftUIInstrumentation.shared.isInstrumentationEnabled else {
      return
    }

    let appearTime = Date()

    let tracer = OpenTelemetry.instance.tracerProvider.get(
      instrumentationName: instrumentationName,
      instrumentationVersion: instrumentationVersion
    )

    // Create root span on first appear if it doesn't exist
    if state.rootSpan == nil {
      let rootSpan = tracer.spanBuilder(spanName: viewName)
        .setSpanKind(spanKind: .client)
        .setStartTime(time: state.initializationTime)
        .startSpan()

      // Add attributes to root span
      for (key, value) in attributes {
        rootSpan.setAttribute(key: key, value: value)
      }
      rootSpan.setAttribute(key: "view.name", value: viewName)
      rootSpan.setAttribute(key: "view.type", value: "swiftui")

      state.rootSpan = rootSpan
    }

    // Create .onAppear child span
    if let rootSpan = state.rootSpan {
      let onAppearSpan = tracer.spanBuilder(spanName: "\(viewName).onAppear")
        .setParent(rootSpan)
        .setSpanKind(spanKind: .client)
        .setStartTime(time: appearTime)
        .startSpan()

      onAppearSpan.setAttribute(key: "view.lifecycle", value: "onAppear")
      onAppearSpan.setAttribute(key: "view.appear.count", value: state.appearCount + 1)
      onAppearSpan.end()
    }

    state.appearCount += 1
  }

  private func handleViewDisappear() {
    // Check if SwiftUI instrumentation is enabled
    guard SwiftUIInstrumentation.shared.isInstrumentationEnabled else {
      return
    }

    let disappearTime = Date()

    let tracer = OpenTelemetry.instance.tracerProvider.get(
      instrumentationName: instrumentationName,
      instrumentationVersion: instrumentationVersion
    )

    // Create .onDisappear child span
    if let rootSpan = state.rootSpan {
      let onDisappearSpan = tracer.spanBuilder(spanName: "\(viewName).onDisappear")
        .setParent(rootSpan)
        .setSpanKind(spanKind: .client)
        .setStartTime(time: disappearTime)
        .startSpan()

      onDisappearSpan.setAttribute(key: "view.lifecycle", value: "onDisappear")
      onDisappearSpan.setAttribute(key: "view.disappear.count", value: state.disappearCount + 1)
      onDisappearSpan.end()

      // End the root span when view disappears
      rootSpan.end(time: disappearTime)
      state.rootSpan = nil
    }

    state.disappearCount += 1
  }
}
