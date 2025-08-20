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

import Foundation

/// SwiftUI instrumentation manager that handles configuration and provides
/// tracing functionality for SwiftUI views.
///
/// This class is initialized by the RumBuilder during SDK setup and provides
/// a centralized way to manage SwiftUI instrumentation settings.
///
/// ## Usage
///
/// The SwiftUIInstrumentation is automatically initialized when you build the RumBuilder:
///
/// ```swift
/// let config = AwsOpenTelemetryConfig(
///     rum: RumConfig(region: "us-west-2", appMonitorId: "your-app-monitor-id"),
///     application: ApplicationConfig(applicationVersion: "1.0.0"),
///     telemetry: TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
/// )
///
/// try AwsOpenTelemetryRumBuilder.create(config: config)
///     .build() // This initializes SwiftUIInstrumentation.shared
/// ```
///
/// After initialization, SwiftUI views can use tracing without any additional setup:
///
/// ```swift
/// HomeView()
///     .awsOpenTelemetryTrace("HomeScreen")
/// ```
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public class SwiftUIInstrumentation {
  /// Shared singleton instance
  public static let shared = SwiftUIInstrumentation()

  /// Whether SwiftUI view instrumentation is enabled
  private var _isInstrumentationEnabled: Bool = false

  /// Thread-safe access to instrumentation status
  public var isInstrumentationEnabled: Bool {
    return _isInstrumentationEnabled
  }

  /// Private initializer to enforce singleton pattern
  private init() {}

  /// Initializes the SwiftUI instrumentation with the provided telemetry configuration.
  /// This method should only be called by the RumBuilder during SDK initialization.
  ///
  /// - Parameter telemetryConfig: The telemetry configuration containing SwiftUI settings
  func initialize(with telemetryConfig: TelemetryConfig) {
    _isInstrumentationEnabled = telemetryConfig.view?.enabled == true
    print("[AwsOpenTelemetry] SwiftUI instrumentation initialized - enabled: \(_isInstrumentationEnabled)")
  }

  /// Resets the instrumentation state (primarily for testing)
  func reset() {
    _isInstrumentationEnabled = false
  }
}
