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

/// SwiftUI View extensions for AWS OpenTelemetry tracing.
/// Wraps views with `AwsOTelTraceView` for performance monitoring.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension SwiftUI.View {
  /// Applies OpenTelemetry tracing to this view.
  /// - Parameter screenName: Stable identifier for trace dashboards
  /// - Returns: View with tracing instrumentation
  func awsOpenTelemetryTrace(_ screenName: String) -> some SwiftUI.View {
    AwsOTelTraceView(screenName) {
      self
    }
  }

  /// Applies OpenTelemetry tracing with string attributes (auto-converted to AttributeValue).
  func awsOpenTelemetryTrace(_ screenName: String,
                             attributes: [String: String]) -> some SwiftUI.View {
    AwsOTelTraceView(screenName, attributes: attributes) {
      self
    }
  }

  /// Applies OpenTelemetry tracing with typed AttributeValue attributes.
  func awsOpenTelemetryTrace(_ screenName: String,
                             attributes: [String: AttributeValue]) -> some SwiftUI.View {
    AwsOTelTraceView(screenName, attributes: attributes) {
      self
    }
  }
}
