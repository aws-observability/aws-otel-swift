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
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) app launch diagnostic(s)")

      for launch in diagnostics {
        guard let endTime = appBecameActiveTime else {
          // Cache first diagnostic to prevent race condition
          if cachedLaunchDiagnostic == nil {
            cachedLaunchDiagnostic = launch
            AwsOpenTelemetryLogger.debug("Caching app launch diagnostic - waiting for app to become active")
          }
          continue
        }

        let launchDurationSeconds = launch.launchDuration.converted(to: .seconds).value

        // Discard abnormally long launches. This may happen in pre-warm launches.
        guard launchDurationSeconds <= 180 else {
          AwsOpenTelemetryLogger.debug("Skipping app launch span - duration too long: \(launchDurationSeconds)s")
          continue
        }
        let startTime = endTime.addingTimeInterval(-launchDurationSeconds)
        let launchType = isColdStart ? "COLD" : "WARM"

        AwsOpenTelemetryLogger.debug("Creating app launch span with duration \(launchDurationSeconds)s")
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
