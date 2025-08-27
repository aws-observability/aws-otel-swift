#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi

  @available(iOS 14.0, *)
  class AwsMetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    private let config: AwsMetricKitConfig

    init(config: AwsMetricKitConfig = .default) {
      self.config = config
      super.init()
      AwsOpenTelemetryLogger.debug("Successfully initialized")
    }

    func subscribe() {
      AwsOpenTelemetryLogger.debug("Registering with MXMetricManager")
      MXMetricManager.shared.add(self)
      AwsOpenTelemetryLogger.debug("Successfully registered with MXMetricManager")
    }

    deinit {
      AwsOpenTelemetryLogger.debug("Unregistering from MXMetricManager")
      MXMetricManager.shared.remove(self)
      AwsOpenTelemetryLogger.debug("Successfully deinitialized")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
      AwsOpenTelemetryLogger.debug("Received \(payloads.count) diagnostic payload(s)")
      for payload in payloads {
        AwsOpenTelemetryLogger.debug("Processing diagnostic payload from \(payload.timeStampBegin) to \(payload.timeStampEnd)")
        AwsOpenTelemetryLogger.debug("Crash diagnostics count: \(payload.crashDiagnostics?.count ?? 0)")
        AwsOpenTelemetryLogger.debug("Hang diagnostics count: \(payload.hangDiagnostics?.count ?? 0)")
        AwsOpenTelemetryLogger.debug("CPU exception diagnostics count: \(payload.cpuExceptionDiagnostics?.count ?? 0)")
        AwsOpenTelemetryLogger.debug("Disk write exception diagnostics count: \(payload.diskWriteExceptionDiagnostics?.count ?? 0)")
        if #available(iOS 16.0, *) {
          AwsOpenTelemetryLogger.debug("App launch diagnostics count: \(payload.appLaunchDiagnostics?.count ?? 0)")
        }

        if config.crashes {
          processCrashDiagnostics(payload.crashDiagnostics)
        }
        processHangDiagnostics(payload.hangDiagnostics)
        processCpuExceptionDiagnostics(payload.cpuExceptionDiagnostics)
        processDiskWriteExceptionDiagnostics(payload.diskWriteExceptionDiagnostics)
        if #available(iOS 16.0, *) {
          processAppLaunchDiagnostics(payload.appLaunchDiagnostics)
        }
      }
    }

    private func processCrashDiagnostics(_ diagnostics: [MXCrashDiagnostic]?) {
      AwsMetricKitCrashProcessor.processCrashDiagnostics(diagnostics)
    }

    private func processHangDiagnostics(_ diagnostics: [MXHangDiagnostic]?) {
      guard let diagnostics else { return }
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) hang diagnostic(s)")
    }

    private func processCpuExceptionDiagnostics(_ diagnostics: [MXCPUExceptionDiagnostic]?) {
      guard let diagnostics else { return }
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) CPU exception diagnostic(s)")
    }

    private func processDiskWriteExceptionDiagnostics(_ diagnostics: [MXDiskWriteExceptionDiagnostic]?) {
      guard let diagnostics else { return }
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) disk write exception diagnostic(s)")
    }

    @available(iOS 16.0, *)
    private func processAppLaunchDiagnostics(_ diagnostics: [MXAppLaunchDiagnostic]?) {
      guard let diagnostics else { return }
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) app launch diagnostic(s)")
    }
  }
#endif
