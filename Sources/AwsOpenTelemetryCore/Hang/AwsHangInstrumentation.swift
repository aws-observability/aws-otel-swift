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

/// Instrumentation for detecting and reporting application hangs
public class AwsHangInstrumentation {
  let tracer: Tracer
  let logger: Logger

  let hangThreshold: CFAbsoluteTime = 0.25 // 250ms
  let hangPredetectionThreshold: CFAbsoluteTime
  var _hangStart: CFAbsoluteTime?
  var _rawStackTrace: Data?
  let syncQueue = DispatchQueue(label: "\(AwsInstrumentationScopes.HANG).sync")
  let watchdogQueue = DispatchQueue(label: AwsInstrumentationScopes.HANG, qos: .userInitiated)

  var hangStart: CFAbsoluteTime? {
    get { syncQueue.sync { _hangStart } }
    set { syncQueue.sync { _hangStart = newValue } }
  }

  var rawStackTrace: Data? {
    get { syncQueue.sync { _rawStackTrace } }
    set { syncQueue.sync { _rawStackTrace = newValue } }
  }

  let stackTraceCollector: LiveStackTraceReporter
  var monitoringTimer: DispatchSourceTimer?

  static let shared = AwsHangInstrumentation()

  public init(stackTraceCollector: LiveStackTraceReporter? = nil) {
    let collector: LiveStackTraceReporter
    if let stackTraceCollector {
      collector = stackTraceCollector
    } else {
      #if !os(watchOS)
        collector = PLLiveStackTraceReporter()
      #else
        collector = NoopLiveStackTraceReporter()
      #endif
    }
    hangPredetectionThreshold = hangThreshold * 2 / 3 // lower threshold to collect stacktrace during ongoing hangs
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsInstrumentationScopes.HANG)
    logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsInstrumentationScopes.HANG)
    self.stackTraceCollector = collector
    startWatchdog()
  }

  func startWatchdog() {
    DispatchQueue.main.async {
      self.setupRunLoopObserver()
    }

    watchdogQueue.async {
      self.startBackgroundMonitoring()
    }
  }

  // We use run loop hang to report hangs because of its precision and ability to
  // handle edge cases without much hassle (e.g. when application is moved to background)
  func setupRunLoopObserver() {
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
          reportHang(startTime: hangStart, endTime: now)
        }
        self.hangStart = nil // if main thread is resolved, then there is no ongoing hang anymore
        rawStackTrace = nil // if main thread is resolved, then any cached stack trace is no longer relevant
      }
    }

    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
  }

  // We need to use the "background ping" strategy to preemptively collect the live stack
  // trace before the main thread has recovered. This must be done from a background thread
  // because the main thread is obviously unavailable during a hang.
  func startBackgroundMonitoring() {
    monitoringTimer = DispatchSource.makeTimerSource(queue: watchdogQueue)
    monitoringTimer?.schedule(deadline: .now(), repeating: .milliseconds(100))
    monitoringTimer?.setEventHandler { [weak self] in
      self?.checkForOngoingHang()
    }
    monitoringTimer?.resume()
  }

  func checkForOngoingHang() {
    // There must be an ongoing hang
    guard let hangStart else {
      return
    }

    let now = CFAbsoluteTimeGetCurrent()
    let hangDuration = now - hangStart

    // We only need to record stack trace once per hang
    guard rawStackTrace == nil else {
      return
    }

    // Collect the live stack trace because there is an ongoing hang that is likely to exceed our hang threshold
    if hangDuration >= hangPredetectionThreshold { // We rely on LiveStackTraceReporter to safely generate live reports
      guard let liveReportData = stackTraceCollector.generateLiveStackTrace() else {
        AwsOpenTelemetryLogger.debug("Failed to generate live stack trace")
        return
      }
      rawStackTrace = liveReportData
    }
  }

  func reportHang(startTime: CFAbsoluteTime, endTime: CFAbsoluteTime) {
    if let stackTrace = rawStackTrace {
      DispatchQueue.main.async {
        let span = self.tracer.spanBuilder(spanName: AwsHangSemConv.name)
          .setStartTime(time: Date(timeIntervalSinceReferenceDate: startTime))
          .setAttribute(key: AwsHangSemConv.type, value: "hang")
          .startSpan()

        // Offload formatting work in case thread is still experiencing jitter
        let liveStackTrace = self.stackTraceCollector.formatStackTrace(rawStackTrace: stackTrace)
        span.setAttribute(key: AwsHangSemConv.message, value: liveStackTrace.message)
        span.setAttribute(key: AwsHangSemConv.stacktrace, value: liveStackTrace.stacktrace)
        span.end(time: Date(timeIntervalSinceReferenceDate: endTime))
      }
    } else {
      let span = tracer.spanBuilder(spanName: AwsHangSemConv.name)
        .setStartTime(time: Date(timeIntervalSinceReferenceDate: startTime))
        .setAttribute(key: AwsHangSemConv.type, value: "hang")
        .setAttribute(key: AwsHangSemConv.message, value: "Hang detected at unknown location")
        .setAttribute(key: AwsHangSemConv.stacktrace, value: "No stack trace captured")
        .startSpan()
      span.end(time: Date(timeIntervalSinceReferenceDate: endTime))
    }
  }
}
