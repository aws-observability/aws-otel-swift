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
      }
      AwsInternalLogger.debug("Successfully initialized")
    }

    func subscribe() {
      AwsInternalLogger.debug("Registering with MXMetricManager")
      MXMetricManager.shared.add(self)
      AwsInternalLogger.debug("Successfully registered with MXMetricManager")
    }

    deinit {
      AwsInternalLogger.debug("Unregistering from MXMetricManager")
      MXMetricManager.shared.remove(self)
      AwsInternalLogger.debug("Successfully deinitialized")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
      AwsInternalLogger.debug("Received \(payloads.count) diagnostic payload(s)")
      for payload in payloads {
        // Disable MXCrashDiagnostic for beta scope
        // if config.crashes {
        //   processCrashDiagnostics(payload.crashDiagnostics)
        // }

        if config.hangs {
          processHangDiagnostics(payload.hangDiagnostics)
        }
      }
    }

    private func processCrashDiagnostics(_ diagnostics: [MXCrashDiagnostic]?) {
      AwsMetricKitCrashProcessor.processCrashDiagnostics(diagnostics)
    }

    private func processHangDiagnostics(_ diagnostics: [MXHangDiagnostic]?) {
      AwsMetricKitHangProcessor.processHangDiagnostics(diagnostics)
    }

    // @available(iOS 16.0, *)
    // private func processAppLaunchDiagnostics(_ diagnostics: [MXAppLaunchDiagnostic]?) {
    //   if config.startup {
    //     AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics(diagnostics)
    //   }
    // }
  }
#endif
