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
import CrashReporter

/// Instrumentation for detecting and reporting application hangs
public class HangInstrumentation {
  private let tracer: Tracer
  private let logger: Logger

  private let hangThreshold: CFAbsoluteTime = 0.25 // 250ms
  private let hangPredetectionThreshold: CFAbsoluteTime
  private var _hangStart: CFAbsoluteTime?
  private var _rawStackTrace: Data?
  private let syncQueue = DispatchQueue(label: "\(AwsInstrumentationScopes.HANG).sync")
  private let watchdogQueue = DispatchQueue(label: AwsInstrumentationScopes.HANG, qos: .userInitiated)

  private let maxStackTraceLines = 200

  private var hangStart: CFAbsoluteTime? {
    get { syncQueue.sync { _hangStart } }
    set { syncQueue.sync { _hangStart = newValue } }
  }

  private var rawStackTrace: Data? {
    get { syncQueue.sync { _rawStackTrace } }
    set { syncQueue.sync { _rawStackTrace = newValue } }
  }

  private let crashReporter: PLCrashReporter
  private var monitoringTimer: DispatchSourceTimer?

  static let shared = HangInstrumentation()

  public init() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Initializing")
    hangPredetectionThreshold = hangThreshold * 2 / 3 // lower threshold to collect stacktrace during ongoing hangs
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsInstrumentationScopes.HANG)
    logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsInstrumentationScopes.HANG)
    let config = PLCrashReporterConfig(signalHandlerType: .BSD, symbolicationStrategy: []) // set this to `.all` (2 sec delay) or `.symbolTable` (1 sec delay) during development for on-device symbolication
    crashReporter = PLCrashReporter(configuration: config)
    startWatchdog()
  }

  private func startWatchdog() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Starting watchdog")

    DispatchQueue.main.async {
      self.setupRunLoopObserver()
    }

    watchdogQueue.async {
      self.startBackgroundMonitoring()
    }
  }

  // We use run loop hang to report hangs because of its precision and ability to
  // handle edge cases without much hassle (e.g. when application is moved to background)
  private func setupRunLoopObserver() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Setting up RunLoop observer")
    let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.afterWaiting.rawValue, true, 0) { [weak self] _, activity in
      guard let self else { return }

      let now = CFAbsoluteTimeGetCurrent()

      if activity == CFRunLoopActivity.afterWaiting {
        hangStart = now
      } else if activity == CFRunLoopActivity.beforeWaiting {
        guard let hangStart else {
          AwsOpenTelemetryLogger.debug("Activity is BeforeWaiting without hangStart")
          return
        }
        let hangDuration = now - hangStart
        if hangDuration >= hangThreshold {
          AwsOpenTelemetryLogger.debug("RunLoop reporter detected hang of \(Int(hangDuration * 1000))ms")
          reportHang(startTime: hangStart, endTime: now)
        }
        self.hangStart = nil // there is no ongoing work, so there is no ongoing hang
        rawStackTrace = nil // if thread resolved, then the stack trace is no longer relevant
      }
    }

    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
  }

  // We need to use the "background ping" strategy so that we have enough time to
  // collect the relevant stack trace before the application has recovered from the hang.
  private func startBackgroundMonitoring() {
    AwsOpenTelemetryLogger.debug("Starting background monitoring")

    monitoringTimer = DispatchSource.makeTimerSource(queue: watchdogQueue)
    monitoringTimer?.schedule(deadline: .now(), repeating: .milliseconds(100))
    monitoringTimer?.setEventHandler { [weak self] in
      self?.checkForHang()
    }
    monitoringTimer?.resume()
  }

  private func checkForHang() {
    guard let hangStart else {
      // There must be an ongoing hang
      return
    }

    let now = CFAbsoluteTimeGetCurrent()
    let hangDuration = now - hangStart

    guard rawStackTrace == nil else {
      // We only need to record stack trace once per hang
      return
    }

    // We need ~20 ms to record the live stack trace during an ongoing app hang, so we need a lower detection threshold
    if hangDuration >= hangPredetectionThreshold {
      AwsOpenTelemetryLogger.debug("Ping reporter detected hang of \(Int(hangDuration * 1000))ms")

      guard let liveReportData = crashReporter.generateLiveReport() else {
        AwsOpenTelemetryLogger.debug("Failed to generate live crash report")
        return
      }
      let stackTraceFinish = CFAbsoluteTimeGetCurrent()
      rawStackTrace = liveReportData
      let span = tracer.spanBuilder(spanName: "[DEBUG] Cached a live stack trace")
        .setStartTime(time: Date(timeIntervalSinceReferenceDate: now))
        .startSpan()
      span.end(time: Date(timeIntervalSinceReferenceDate: stackTraceFinish))
      AwsOpenTelemetryLogger.debug("Captured raw stack trace in \(Int((stackTraceFinish - now) * 1000))ms")
    }
  }

  private func reportHang(startTime: CFAbsoluteTime, endTime: CFAbsoluteTime) {
    var stacktrace = "No stack trace captured"

    let span = tracer.spanBuilder(spanName: "device.hang")
      .setStartTime(time: Date(timeIntervalSinceReferenceDate: startTime))
      .setAttribute(key: "exception.type", value: "hang")
      .setAttribute(key: "exception.message", value: "Hang detected at unknown location")
      .startSpan()
    if let rawStackTrace {
      DispatchQueue.main.async {
        do {
          // Offload formatting work
          let crashReport = try PLCrashReport(data: rawStackTrace)
          if let fullStacktrace = PLCrashReportTextFormatter.stringValue(for: crashReport, with: PLCrashReportTextFormatiOS) {
            stacktrace = fullStacktrace.split(separator: "\n").prefix(self.maxStackTraceLines).joined(separator: "\n")
            let firstFrame = stacktrace.components(separatedBy: "Thread 0:\n").dropFirst().first?.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) ?? "unknown location"
            span.setAttribute(key: "exception.message", value: "Hang detected at \(firstFrame)")
          }
        } catch {
          span.setAttribute(key: "hang.stacktrace", value: "Failed to parse stack trace: \(error)")
        }

        span.setAttribute(key: "hang.stacktrace", value: stacktrace)
        span.end(time: Date(timeIntervalSinceReferenceDate: endTime))
        AwsOpenTelemetryLogger.debug("Recorded app hang")
      }

    } else {
      span.setAttribute(key: "hang.stacktrace", value: stacktrace)
      span.end(time: Date(timeIntervalSinceReferenceDate: endTime))
      return
    }
  }
}
