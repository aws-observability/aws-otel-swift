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

/// SwiftUI View extensions for AWS OpenTelemetry performance tracing.
///
/// These extensions provide a convenient way to add performance monitoring to any SwiftUI view
/// without changing the existing view hierarchy. The extensions wrap the view with
/// `AwsOpenTelemetryTraceView` to capture performance metrics.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {
  /// Applies AWS OpenTelemetry tracing to this view for performance monitoring.
  ///
  /// This method wraps the view with `AwsOpenTelemetryTraceView` to capture:
  /// - **Root span** tracking complete view lifecycle (init → onDisappear)
  /// - **Body spans** for each SwiftUI body re-evaluation (can be multiple)
  /// - **Lifecycle spans** for onAppear and onDisappear events
  ///
  /// **Example Usage:**
  /// ```swift
  /// HomeView()
  ///     .awsOpenTelemetryTrace("HomeScreen")
  ///
  /// ProfileView(user: user)
  ///     .awsOpenTelemetryTrace("ProfileDetail", stringAttributes: [
  ///         "user_id": user.id,
  ///         "user_type": user.type
  ///     ])
  /// ```
  ///
  /// **Best Practices:**
  /// - Use stable, meaningful view names (e.g., "HomeScreen", "ProfileDetail")
  /// - Apply to performance-critical screens rather than every small component
  /// - Include relevant contextual attributes for better analysis
  /// - Avoid on frequently re-rendered views to prevent performance impact
  ///
  /// - Parameters:
  ///   - viewName: The stable identifier used in trace dashboards
  /// - Returns: A view with tracing instrumentation applied
  func awsOpenTelemetryTrace(_ viewName: String) -> some View {
    AwsOpenTelemetryTraceView(viewName, attributes: [:] as [String: String]) {
      self
    }
  }

  /// Applies AWS OpenTelemetry tracing to this view with string attributes.
  ///
  /// Convenience method with string attributes that are automatically converted
  /// to `AttributeValue.string()`.
  ///
  /// **Example Usage:**
  /// ```swift
  /// ProfileView(user: user)
  ///     .awsOpenTelemetryTrace("ProfileDetail", stringAttributes: [
  ///         "user_id": user.id,
  ///         "user_type": user.type
  ///     ])
  /// ```
  ///
  /// - Parameters:
  ///   - viewName: The stable identifier used in trace dashboards
  ///   - stringAttributes: String metadata to associate with spans
  /// - Returns: A view with tracing instrumentation applied
  func awsOpenTelemetryTrace(_ viewName: String,
                             stringAttributes: [String: String]) -> some View {
    AwsOpenTelemetryTraceView(viewName, attributes: stringAttributes) {
      self
    }
  }

  /// Applies AWS OpenTelemetry tracing to this view with AttributeValue attributes.
  ///
  /// Advanced method that allows you to specify attributes with specific types.
  ///
  /// **Example Usage:**
  /// ```swift
  /// ProfileView(user: user)
  ///     .awsOpenTelemetryTrace("ProfileDetail", attributes: [
  ///         "user_id": AttributeValue.string(user.id),
  ///         "user_count": AttributeValue.int(users.count),
  ///         "is_premium": AttributeValue.bool(user.isPremium)
  ///     ])
  /// ```
  ///
  /// - Parameters:
  ///   - viewName: The stable identifier used in trace dashboards
  ///   - attributes: Typed metadata to associate with spans
  /// - Returns: A view with tracing instrumentation applied
  func awsOpenTelemetryTrace(_ viewName: String,
                             attributes: [String: AttributeValue]) -> some View {
    AwsOpenTelemetryTraceView(viewName, attributes: attributes) {
      self
    }
  }
}
