import Foundation
import OpenTelemetryApi
import KSCrashInstallations

class KSCrashInstrumentation {
  static let scopeName = "KSCrash"
  private static var isInstalled = false

  static func install() {
    guard !isInstalled else {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation already installed")
      return
    }
    isInstalled = true

    AwsOpenTelemetryLogger.debug("Installing KSCrashInstrumentation")

    // Set up email installation
    let emailInstallation = CrashInstallationEmail.shared
    emailInstallation.recipients = ["aws-rum-dev@amzn.com", "williamz.zhou1@gmail.com"]
    emailInstallation.setReportStyle(.apple, useDefaultFilenameFormat: true)

    // Set up console installation for testing
    let consoleInstallation = CrashInstallationConsole.shared
    consoleInstallation.printAppleFormat = true

    // Install crash reporting
    let config = KSCrashConfiguration()
    config.monitors = [.machException, .signal]

    do {
      try emailInstallation.install(with: config)
      try consoleInstallation.install(with: config)
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation installed successfully")
    } catch {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation failed to install: \(error)")
    }

    // Process any stored crashes and convert to OpenTelemetry logs
    processStoredCrashes()
  }

  private static func processStoredCrashes() {
    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation processing stored crashes from KSCrash")

    guard let reportStore = KSCrash.shared.reportStore else {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation no report store available")
      return
    }

    let reportIDs = reportStore.reportIDs
    guard !reportIDs.isEmpty else {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation no stored crashes found")
      return
    }

    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation processing \(reportIDs.count) stored crashes")

    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scopeName)

    for (index, reportID) in reportIDs.enumerated() {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation processing stored crash \(index + 1)/\(reportIDs.count)")

      guard let crashReport = reportStore.report(for: reportID.int64Value) else {
        AwsOpenTelemetryLogger.debug("KSCrashInstrumentation could not load crash report \(reportID)")
        continue
      }

      var attributes: [String: AttributeValue] = [:]
      let reportDict = crashReport.value

      // Extract crash information from KSCrash report
      if let crash = reportDict["crash"] as? [String: Any] {
        if let error = crash["error"] as? [String: Any] {
          if let signal = error["signal"] as? [String: Any],
             let signalName = signal["name"] as? String {
            attributes["crash.signal"] = AttributeValue.string(signalName)
          }

          if let type = error["type"] as? String {
            attributes["exception.type"] = AttributeValue.string(type)
          }

          if let reason = error["reason"] as? String {
            attributes["exception.message"] = AttributeValue.string(reason)
          }
        }

        // Extract stack trace
        if let threads = crash["threads"] as? [[String: Any]] {
          let stackTrace = threads.compactMap { thread -> String? in
            if let backtrace = thread["backtrace"] as? [String: Any],
               let contents = backtrace["contents"] as? [[String: Any]] {
              return contents.compactMap { frame in
                frame["symbol_name"] as? String
              }.joined(separator: "\n")
            }
            return nil
          }.joined(separator: "\n")

          if !stackTrace.isEmpty {
            let maxBytes = 30720 // 30KB
            let truncatedStackTrace = stackTrace.count > maxBytes ? String(stackTrace.prefix(maxBytes)) : stackTrace
            attributes["exception.stacktrace"] = AttributeValue.string(truncatedStackTrace)
          }
        }
      }

      // Use report timestamp or current time
      let timestamp = reportDict["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
      let crashTime = Date(timeIntervalSince1970: timestamp)

      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation emitting stored crash with \(attributes.count) attributes")
      logger.logRecordBuilder()
        .setEventName("device.crash")
        .setTimestamp(crashTime)
        .setAttributes(attributes)
        .emit()
    }

    // Delete all processed crash reports
    reportStore.deleteAllReports()
    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation processed and removed \(reportIDs.count) stored crashes")
  }
}
