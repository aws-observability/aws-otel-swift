import Foundation
import OpenTelemetryApi

#if canImport(KSCrashRecording)
  import KSCrashRecording
#elseif canImport(KSCrash)
  import KSCrash
#endif

#if canImport(KSCrashFilters)
  import KSCrashFilters
#endif

class KSCrashInstrumentation {
  static let scopeName = "software.amazon.opentelemetry.KSCrash"
  private static var isInstalled = false
  private static let reporter = KSCrash.shared

  static func updateUserInfo() {
    var userInfo: [String: Any] = [:]

    // Add session ID
    let session = AwsSessionManagerProvider.getInstance().getSession()
    userInfo["session_id"] = session.id

    // Add user ID
    let uidManager = AwsUIDManagerProvider.getInstance()
    userInfo["user_id"] = uidManager.getUID()

    reporter.userInfo = userInfo
    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation updated user info: \(userInfo)")
  }

  static func install() {
    guard !isInstalled else {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation already installed")
      return
    }

    AwsOpenTelemetryLogger.debug("Installing KSCrashInstrumentation")

    do {
      let config = KSCrashConfiguration()
      config.enableSigTermMonitoring = false
      config.enableSwapCxaThrow = false

      try reporter.install(with: config)
      isInstalled = true
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation installed successfully")
    } catch {
      AwsOpenTelemetryLogger.error("KSCrashInstrumentation failed to install: \(error)")
      return
    }

    // Set initial user info
    updateUserInfo()

    // Process any stored crashes asynchronously
    DispatchQueue.global(qos: .utility).async {
      processStoredCrashes()
    }
  }

  private static func processStoredCrashes() {
    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation KSCrash installed: \(isInstalled)")
    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation KSCrash crashed last launch: \(reporter.crashedLastLaunch)")

    guard let reportStore = reporter.reportStore else {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation no report store available")
      return
    }

    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation report store available, checking for reports")
    let reportIDs = reportStore.reportIDs
    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation found \(reportIDs.count) report IDs: \(reportIDs)")

    guard !reportIDs.isEmpty else {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation no stored crashes found")
      return
    }

    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation processing \(reportIDs.count) stored crashes")

    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scopeName)

    for (index, reportID) in reportIDs.enumerated() {
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation processing crash report \(index + 1)/\(reportIDs.count)")

      guard let id = reportID as? Int64,
            let crashReport = reportStore.report(for: id) else {
        AwsOpenTelemetryLogger.debug("KSCrashInstrumentation failed to load crash report \(reportID)")
        continue
      }

      var attributes: [String: AttributeValue] = [:]
      let reportDict = crashReport.value

      // Extract crash information
      if let crash = reportDict["crash"] as? [String: Any] {
        if let error = crash["error"] as? [String: Any] {
          if let signal = error["signal"] as? [String: Any] {
            if let signalName = signal["name"] as? String {
              attributes["crash.signal"] = AttributeValue.string(signalName)
              AwsOpenTelemetryLogger.debug("KSCrashInstrumentation extracted signal: \(signalName)")
            }
            if let signalCode = signal["code"] as? Int {
              attributes["crash.signal_code"] = AttributeValue.int(signalCode)
            }
          }

          if let type = error["type"] as? String {
            attributes["exception.type"] = AttributeValue.string(type)
            AwsOpenTelemetryLogger.debug("KSCrashInstrumentation extracted exception type: \(type)")
          }

          if let reason = error["reason"] as? String, !reason.isEmpty {
            attributes["exception.message"] = AttributeValue.string(reason)
            AwsOpenTelemetryLogger.debug("KSCrashInstrumentation extracted exception reason: \(reason)")
          } else {
            // Create fallback message from signal and type
            var fallbackMessage = "Crash detected"
            if let signal = error["signal"] as? [String: Any],
               let signalName = signal["name"] as? String {
              fallbackMessage = "\(signalName) signal"
            }
            if let type = error["type"] as? String {
              fallbackMessage += " (\(type))"
            }
            attributes["exception.message"] = AttributeValue.string(fallbackMessage)
            AwsOpenTelemetryLogger.debug("KSCrashInstrumentation created fallback message: \(fallbackMessage)")
          }

          if let address = error["address"] as? Int64 {
            attributes["crash.address"] = AttributeValue.string(String(format: "0x%llx", address))
          }
        }
      }

      // Extract user information if available
      if let user = reportDict["user"] as? [String: Any] {
        // Extract session and user IDs specifically
        if let sessionId = user["session_id"] as? String {
          attributes["session.id"] = AttributeValue.string(sessionId)
          AwsOpenTelemetryLogger.debug("KSCrashInstrumentation extracted session ID: \(sessionId)")
        }
        if let userId = user["user_id"] as? String {
          attributes["user.id"] = AttributeValue.string(userId)
          AwsOpenTelemetryLogger.debug("KSCrashInstrumentation extracted user ID: \(userId)")
        }
      }

      // Add JSON representation of crash report
      // do {
      //   let jsonData = try JSONSerialization.data(withJSONObject: reportDict, options: [.prettyPrinted])
      //   if let jsonString = String(data: jsonData, encoding: .utf8) {
      //     attributes["exception.json"] = AttributeValue.string(jsonString)
      //   }
      // } catch {
      //   AwsOpenTelemetryLogger.debug("KSCrashInstrumentation failed to serialize JSON: \(error)")
      // }

      // Use KSCrash's Apple formatter
      let filter = CrashReportFilterAppleFmt()
      let semaphore = DispatchSemaphore(value: 0)
      var appleFormatReport: String?

      filter.filterReports([crashReport]) { reports, _ in
        if let reports,
           let firstReport = reports.first as? CrashReportString {
          appleFormatReport = firstReport.value
        }
        semaphore.signal()
      }

      _ = semaphore.wait(timeout: .now() + 1.0)
      let finalReport = appleFormatReport ?? "Failed to format crash report"

      attributes["exception.stacktrace"] = AttributeValue.string(finalReport)

      // Get timestamp
      let timestamp: Date = if let reportTimestamp = reportDict["timestamp"] as? String {
        dateFormatter.date(from: reportTimestamp) ?? Date()
      } else {
        Date()
      }

      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation emitting crash log with \(attributes.count) attributes")
      logger.logRecordBuilder()
        .setEventName("device.crash")
        .setTimestamp(timestamp)
        .setAttributes(attributes)
        .emit()

      // Delete processed report
      reportStore.deleteReport(with: id)
      AwsOpenTelemetryLogger.debug("KSCrashInstrumentation deleted processed crash report \(id)")
    }

    AwsOpenTelemetryLogger.debug("KSCrashInstrumentation processed \(reportIDs.count) stored crashes")
  }

  private static var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }
}
