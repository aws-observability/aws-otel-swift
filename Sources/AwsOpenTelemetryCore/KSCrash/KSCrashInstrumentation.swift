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
import OpenTelemetryApi

#if canImport(KSCrashRecording)
  import KSCrashRecording
#elseif canImport(KSCrash)
  import KSCrash
#endif

#if canImport(KSCrashFilters)
  import KSCrashFilters
#endif

protocol CrashProtocol {
  static func install()
  static func cacheCrashContext(session: AwsSession?,
                                userId: String?,
                                screenName: String?)

  static func recoverCrashContext(from rawCrash: [String: Any],
                                  log: LogRecordBuilder,
                                  attributes: [String: AttributeValue]) -> [String: AttributeValue]
  static func processStoredCrashes()
}

public class KSCrashInstrumentation: CrashProtocol {
  public static let maxStackTraceBytes = 30 * 1024 // 30 KB
  public private(set) static var isInstalled: Bool = false
  private static let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsInstrumentationScopes.KSCRASH)
  static let reporter = KSCrash.shared
  static var observers: [NSObjectProtocol] = []
  private static let timestampFormatter: ISO8601DateFormatter = {
    // Example KSCrash timestamp: `2025-10-28T03:30:53.604204Z`
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime,
      .withFractionalSeconds
    ]
    return formatter
  }()

  static func install() {
    guard !isInstalled else {
      AwsInternalLogger.debug("KSCrashInstrumentation already installed")
      return
    }

    do {
      let config = KSCrashConfiguration()
      config.enableSigTermMonitoring = false
      config.enableSwapCxaThrow = false

      try reporter.install(with: config)
      isInstalled = true
    } catch {
      AwsInternalLogger.error("KSCrashInstrumentation failed to install: \(error)")
      return
    }

    // Set initial user info
    cacheCrashContext()

    // Process any stored crashes asynchronously
    DispatchQueue.global(qos: .utility).async {
      processStoredCrashes()
    }

    // setup cache context subscribers
    setupNotificationObservers()
  }

  static func setupNotificationObservers() {
    // Update crash context on session start
    let sessionObserver = NotificationCenter.default.addObserver(
      forName: SessionStartNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let session = notification.object as? AwsSession {
        DispatchQueue.global(qos: .utility).async {
          cacheCrashContext(session: session)
        }
      }
    }
    observers.append(sessionObserver)

    // Update crash context on user change
    let userObserver = NotificationCenter.default.addObserver(
      forName: AwsUserIdChangeNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let userId = notification.object as? String {
        DispatchQueue.global(qos: .utility).async {
          cacheCrashContext(session: nil, userId: userId)
        }
      }
    }
    observers.append(userObserver)

    // Update crash context on screen change
    let screenObserver = NotificationCenter.default.addObserver(
      forName: AwsScreenChangeNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let screen = notification.object as? String {
        DispatchQueue.global(qos: .utility).async {
          cacheCrashContext(session: nil, userId: nil, screenName: screen)
        }
      }
    }
    observers.append(screenObserver)
  }

  static func cacheCrashContext(session: AwsSession? = nil,
                                userId: String? = nil,
                                screenName: String? = nil) {
    var userInfo: [String: Any] = [:]

    // user
    let userId = userId ?? AwsUIDManagerProvider.getInstance().getUID()
    userInfo[AwsUserSemvConv.id] = userId

    // session
    let sessionManager = AwsSessionManagerProvider.getInstance()
    let session = session ?? sessionManager.peekSession() ?? sessionManager.getSession()

    userInfo[AwsSessionSemConv.id] = session.id
    if let prevSessionId = session.previousId {
      userInfo[AwsSessionSemConv.previousId] = prevSessionId
    }

    // screen
    let screen = screenName ?? AwsScreenManagerProvider.getInstance().currentScreen
    userInfo[AwsViewSemConv.screenName] = screen

    reporter.userInfo = userInfo
  }

  /// Report cached crashes from KSCrash store (just a local file)
  static func processStoredCrashes() {
    // Init
    guard let reportStore = reporter.reportStore else {
      AwsInternalLogger.debug("KSCrashInstrumentation no report store available")
      return
    }

    // Pull crash reports
    let reportIDs = reportStore.reportIDs
    for reportID in reportIDs {
      guard let id = reportID as? Int64,
            let crashReport = reportStore.report(for: id) else {
        AwsInternalLogger.debug("KSCrashInstrumentation failed to load crash report \(reportID)")
        continue
      }

      // Report crash as log event
      reportCrash(crashReport: crashReport)

      // Delete processed report
      reportStore.deleteReport(with: id)
    }

    AwsInternalLogger.debug("KSCrashInstrumentation processed \(reportIDs.count) stored crashes")
  }

  // Report a KSCrash report in Apple format
  private static func reportCrash(crashReport: CrashReportDictionary) {
    let rawCrash: [String: Any] = crashReport.value
    let log: any LogRecordBuilder = logger.logRecordBuilder()
      .setEventName("device.crash")

    var attributes: [String: AttributeValue] = [
      AwsExceptionSemConv.type: AttributeValue.string("crash"),
      // When `recovered_context` is true, then the following original attributes will be recovered,
      // and the crash event will be backfilled to the original session.
      // 1. `session.id`
      // 2. `session.previous_id` (if any existed)
      // 3. `user.id`
      // 4. original `timestamp`
      AwsExceptionSemConv.recoveredContext: AttributeValue.bool(false)
    ]

    // Attempt to recovert the original crash context
    attributes = recoverCrashContext(from: rawCrash, log: log, attributes: attributes)

    // Get stack trace in Apple format and emit log event in async callback
    // If the iOS application was built with `strip styles` set to `debugging symbols`, then KSCrash will
    // also perform on-device symbolication.
    CrashReportFilterAppleFmt().filterReports([crashReport]) { reports, _ in
      var appleFormatReport = (reports?.first as? CrashReportString)?.value ?? "Failed to format crash report"
      if appleFormatReport.utf8.count > maxStackTraceBytes {
        appleFormatReport = String(appleFormatReport.utf8.prefix(maxStackTraceBytes)) ?? appleFormatReport
      }
      attributes[AwsExceptionSemConv.stacktrace] = AttributeValue.string(appleFormatReport)

      // Prints the location of the first frame for the thread that crashed. For example,
      // `Crash detected on thread 0 at libswiftCore.dylib 0x000000019ed5c8c4 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172`
      attributes[AwsExceptionSemConv.message] = AttributeValue.string(extractCrashMessage(from: appleFormatReport))

      _ = log.setAttributes(attributes)
      log.emit()
    }
  }

  /// Get first frame of crashed thread for the crash message. This is useful for grouping
  static func extractCrashMessage(from stackTrace: String) -> String {
    let lines = stackTrace.components(separatedBy: "\n")
    guard let crashedLine = lines.first(where: { $0.range(of: #"Thread \d+ Crashed:"#, options: .regularExpression) != nil }),
          let threadMatch = crashedLine.range(of: #"Thread (\d+) Crashed:"#, options: .regularExpression),
          let crashedIndex = lines.firstIndex(of: crashedLine),
          let firstFrame = lines.dropFirst(crashedIndex + 1).first(where: { $0.hasPrefix("0   ") }) else {
      return "Crash detected at unknown location"
    }

    let threadNumber = String(crashedLine[threadMatch]).replacingOccurrences(of: #"Thread (\d+) Crashed:"#, with: "$1", options: .regularExpression)
    let cleanFrame = String(firstFrame.dropFirst(2)) // Remove "0 " prefix
      .replacingOccurrences(of: #"[\s\t]+"#, with: " ", options: .regularExpression) // reduce white spaces to single spaces
      .trimmingCharacters(in: .whitespaces) // trim white spaces
    return "Crash detected on thread \(threadNumber) at \(cleanFrame)"
  }

  /// If sessionId and timestamp can be recovered, then attempt to restore original context.
  /// However, if user session context cannot be recovered, then we use the current timestamp
  /// and let sessions/user id processors do their work. For this edge case, users can look
  /// at the current `session.previous_id` to see if the previous session had crashed.
  static func recoverCrashContext(from rawCrash: [String: Any],
                                  log: LogRecordBuilder,
                                  attributes: [String: AttributeValue]) -> [String: AttributeValue] {
    guard let report = rawCrash["report"] as? [String: Any],
          let timestampString = report["timestamp"] as? String,
          let timestamp = timestampFormatter.date(from: timestampString),
          let userInfo = rawCrash["user"] as? [String: Any],
          let sessionId = userInfo[AwsSessionSemConv.id] as? String else {
      _ = log.setTimestamp(Date()) // just for clarity (upstream already does this)
      AwsInternalLogger.debug("KSCrashInstrumentation failed to recover crash context")
      return attributes
    }
    var mutatedAttributes = attributes

    // required attributes for recovery
    _ = log.setTimestamp(timestamp)
    mutatedAttributes[AwsSessionSemConv.id] = AttributeValue.string(sessionId)

    // `user.id` is only nice-to-have for crash recovery, so we will grab it without blocking the overall recovery attempt
    if let userId = userInfo[AwsUserSemvConv.id] as? String {
      mutatedAttributes[AwsUserSemvConv.id] = AttributeValue.string(userId)
    }

    // `screen.name` is also nice-to-have, and may not exist if a screen had not been registered at the time
    if let screenName = userInfo[AwsViewSemConv.screenName] as? String {
      mutatedAttributes[AwsViewSemConv.screenName] = AttributeValue.string(screenName)
    }

    // `session.previous_id` is also nice-to-have, and may not even exist if there was no previous session
    if let previousSessionId = userInfo[AwsSessionSemConv.previousId] as? String {
      mutatedAttributes[AwsSessionSemConv.previousId] = AttributeValue.string(previousSessionId)
    }

    // Confirms that original context was recovered, since this may not be obvious
    mutatedAttributes[AwsExceptionSemConv.recoveredContext] = AttributeValue.bool(true)
    return mutatedAttributes
  }
}
