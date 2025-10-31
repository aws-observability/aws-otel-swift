#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi

  /*
   * MetriKit is supported in iOSv14, but only iOSv15 support real time monitoring for MXDiagnosticPaylods.
   * From documentation, MetrcKit "delivers diagnostic reports immediately in iOS 15 and later and macOS 12 and later".
   * https://developer.apple.com/documentation/metrickit?language=objc
   */
  @available(iOS 15.0, *)
  class AwsMetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    private let config: AwsMetricKitConfig

    init(config: AwsMetricKitConfig = .default) {
      self.config = config
      super.init()
      if #available(iOS 16.0, *), config.startup {
        AwsMetricKitAppLaunchProcessor.initialize()
      } else {
        AwsInternalLogger.error("ADOT Swift only officially supports iOS 16")
      }
    }

    func subscribe() {
      MXMetricManager.shared.add(self)
    }

    deinit {
      MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
      for payload in payloads {
        // Disable MXCrashDiagnostic for beta scope
        // if config.crashes {
        //   processCrashDiagnostics(payload.crashDiagnostics)
        // }
      }
    }

    private func processCrashDiagnostics(_ diagnostics: [MXCrashDiagnostic]?) {
      AwsMetricKitCrashProcessor.processCrashDiagnostics(diagnostics)
    }
  }
#endif
