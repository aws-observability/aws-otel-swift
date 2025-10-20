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
  private var watchdogTimer: Timer?
  private var hangStart: Date?
  private var lastPing: Date = .init()
  private let hangThreshold: TimeInterval = 0.25 // 250ms
  private let watchdogQueue = DispatchQueue(label: "hang.watchdog", qos: .userInitiated)
  private var stackTrace: String?
  private let crashReporter: PLCrashReporter
  private var hangInProgress = false

  static let shared = HangInstrumentation()

  public init() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Initializing")
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsInstrumentationScopes.HANG)
    logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsInstrumentationScopes.HANG)
    let config = PLCrashReporterConfig(signalHandlerType: .BSD, symbolicationStrategy: .all)
    crashReporter = PLCrashReporter(configuration: config)
    startWatchdog()
  }

  deinit {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Deinitializing")
    stopWatchdog()
  }

  private func startWatchdog() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Starting watchdog")

    DispatchQueue.main.async {
      self.setupRunLoopObserver()
      self.startMainThreadPing()
    }

    watchdogQueue.async {
      self.startBackgroundMonitoring()
    }
  }

  private func setupRunLoopObserver() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Setting up RunLoop observer")
    let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.afterWaiting.rawValue, true, 0) { [weak self] _, activity in
      guard let self else { return }

      let now = Date()

      if activity == CFRunLoopActivity.afterWaiting {
        // AwsOpenTelemetryLogger.debug("HangInstrumentation: RunLoop entering beforeWaiting")
        hangStart = now
      } else if activity == CFRunLoopActivity.beforeWaiting {
        guard let hangStart else {
          AwsOpenTelemetryLogger.debug("Activity is BeforeWaiting without hangStart")
          return
        }

        let hangDuration = now.timeIntervalSince(hangStart)

        if hangDuration >= hangThreshold {
          AwsOpenTelemetryLogger.debug("RunLoop reporter detected hang of \(Int(hangDuration * 1000))ms")
          reportHang(startTime: hangStart, endTime: now)
        }
        self.hangStart = nil
      }
    }

    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
  }

  private func startMainThreadPing() {
    AwsOpenTelemetryLogger.debug("Starting main thread ping")
    watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.lastPing = Date()
    }
  }

  // We have to poll for stack trace for ongoing hang
  private func startBackgroundMonitoring() {
    AwsOpenTelemetryLogger.debug("Starting background monitoring")

    while true {
      // TODO: refactor to set timeout to avoid blocking this background thread
      Thread.sleep(forTimeInterval: 0.1)
      guard let hangStart else {
        // There must be an ongoing hang
        continue
      }

      let now = Date()
      let hangDuration = now.timeIntervalSince(hangStart)

      if hangDuration >= hangThreshold {
        AwsOpenTelemetryLogger.debug("Ping reporter detected hang of \(Int(hangDuration * 1000))ms")

        guard let liveReportData = crashReporter.generateLiveReport() else {
          AwsOpenTelemetryLogger.debug("Failed to generate live crash report")
          continue
        }

        do {
          let liveStackTrace = try PLCrashReport(data: liveReportData)
          if let formatted = PLCrashReportTextFormatter.stringValue(for: liveStackTrace, with: PLCrashReportTextFormatiOS) {
            stackTrace = formatted
            AwsOpenTelemetryLogger.debug("Made a live stack trace!")
            logger.logRecordBuilder()
              .setEventName("[DEBUG] Cached a live stack trace")
              .setTimestamp(now)
              .setAttributes(["exception.stacktrace": AttributeValue.string(formatted)])
              .emit()
          } else {
            AwsOpenTelemetryLogger.debug("Failed to format the stack trace!")
          }
        } catch {
          AwsOpenTelemetryLogger.debug("Failed to make live stack trace: \(error)")
        }

      } else {
        AwsOpenTelemetryLogger.debug("Ping reporter dropping hang of \(Int(hangDuration * 1000))ms")
      }
    }
  }

  private func stopWatchdog() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Stopping watchdog")
    watchdogTimer?.invalidate()
    watchdogTimer = nil
  }

  private func reportHang(startTime: Date, endTime: Date) {
    DispatchQueue.main.async {
      AwsOpenTelemetryLogger.debug("Attempting to record a hang")
      if self.stackTrace != nil {
        AwsOpenTelemetryLogger.debug("Found a stack trace")
      } else {
        AwsOpenTelemetryLogger.debug("Did not find a stack trace")
      }
      let span = self.tracer.spanBuilder(spanName: "device.hang")
        .setStartTime(time: startTime)
        .startSpan()

      span.setAttribute(key: "exception.stacktrace", value: self.stackTrace ?? "No stack trace found")
      span.end(time: endTime)

      self.stackTrace = nil
    }
  }
}
