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

#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi
  import UIKit

  @available(iOS 16.0, *)
  class AwsMetricKitAppLaunchProcessor {
    static let scopeName = AwsInstrumentationScopes.APP_LAUNCH_DIAGNOSTIC
    private static var appBecameActiveTime: Date?
    private static var isColdStart = true
    private static var cachedLaunchDiagnostic: MXAppLaunchDiagnostic?

    static func initialize() {
      NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { _ in
        appBecameActiveTime = Date()

        // Process cached diagnostic if available
        if let cached = cachedLaunchDiagnostic {
          processAppLaunchDiagnostics([cached])
          cachedLaunchDiagnostic = nil
        }
      }
    }

    // For testing purposes only
    static func resetForTesting() {
      isColdStart = true
      appBecameActiveTime = nil
      cachedLaunchDiagnostic = nil
    }

    static func processAppLaunchDiagnostics(_ diagnostics: [MXAppLaunchDiagnostic]?) {
      guard let diagnostics else { return }
      let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: scopeName)

      for launch in diagnostics {
        guard let endTime = appBecameActiveTime else {
          // Cache first diagnostic to prevent race condition
          if cachedLaunchDiagnostic == nil {
            cachedLaunchDiagnostic = launch
          }
          continue
        }

        let launchDurationSeconds = launch.launchDuration.converted(to: .seconds).value

        // Discard abnormally long launches. This may happen in pre-warm launches.
        guard launchDurationSeconds <= 180 else {
          AwsInternalLogger.debug("Skipping app launch span - duration too long: \(launchDurationSeconds)s")
          continue
        }
        let startTime = endTime.addingTimeInterval(-launchDurationSeconds)
        let launchType = isColdStart ? "cold" : "warm"

        let span = tracer.spanBuilder(spanName: "AppStart")
          .setStartTime(time: startTime)
          .setAttribute(key: AwsMetricKitConstants.appLaunchDuration, value: AttributeValue.double(launchDurationSeconds))
          .setAttribute(key: AwsMetricKitConstants.appLaunchType, value: AttributeValue.string(launchType))
          .startSpan()

        span.end(time: endTime)

        // Mark subsequent launches as warm
        isColdStart = false
      }
    }
  }
#endif
