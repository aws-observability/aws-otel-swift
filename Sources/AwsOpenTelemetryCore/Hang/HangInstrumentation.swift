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
public class HangInstrumentation {
  private let tracer: Tracer
  private var watchdogTimer: Timer?
  private var lastActivity: Date = .init()
  private var lastPing: Date = .init()
  private let hangThreshold: TimeInterval = 0.25 // 250ms
  private let watchdogQueue = DispatchQueue(label: "hang.watchdog", qos: .userInitiated)

  static let shared = HangInstrumentation()

  public init() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Initializing")
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsInstrumentationScopes.HANG)
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
        lastActivity = now
      } else if activity == CFRunLoopActivity.beforeWaiting {
        let hangDuration = now.timeIntervalSince(lastActivity)

        if hangDuration >= 0.05 { // 50 ms
          AwsOpenTelemetryLogger.debug("HangInstrumentation: RunLoop entered beforeWaiting, duration: \(Int(hangDuration * 1000))ms")
        }

        if hangDuration >= hangThreshold {
          AwsOpenTelemetryLogger.debug("HangInstrumentation: CFRunLoop detected hang of \(Int(hangDuration * 1000))ms")
          reportHang(startTime: lastActivity, endTime: now, duration: hangDuration, reporter: "cf_run_loop")
        }
      }
    }

    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
  }

  private func startMainThreadPing() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Starting main thread ping")
    watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.lastPing = Date()
    }
  }

  private func startBackgroundMonitoring() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Starting background monitoring")

    while true {
      Thread.sleep(forTimeInterval: 0.1)

      let now = Date()
      let timeSinceLastPing = now.timeIntervalSince(lastPing)

      if timeSinceLastPing >= hangThreshold {
        let hangStart = Date(timeIntervalSince1970: lastPing.timeIntervalSince1970)
        AwsOpenTelemetryLogger.debug("HangInstrumentation: Ping detected hang of \(Int(timeSinceLastPing * 1000))ms")

        // Wait for main thread to recover
        while Date().timeIntervalSince(lastPing) >= hangThreshold {
          Thread.sleep(forTimeInterval: 0.05)
        }

        // Report hang with actual recovery time
        let recoveryTime = Date()
        let actualDuration = recoveryTime.timeIntervalSince(hangStart)
        reportHang(startTime: hangStart, endTime: recoveryTime, duration: actualDuration, reporter: "pings")
      }
    }
  }

  private func stopWatchdog() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Stopping watchdog")
    watchdogTimer?.invalidate()
    watchdogTimer = nil
  }

  private func reportHang(startTime: Date, endTime: Date, duration: TimeInterval, reporter: String) {
    DispatchQueue.main.async {
      let span = self.tracer.spanBuilder(spanName: "device.hang")
        .setStartTime(time: startTime)
        .startSpan()

      span.setAttribute(key: "hang.duration_ms", value: Int(duration * 1000))
      span.setAttribute(key: "hang.reporter", value: reporter)
      span.end(time: endTime)
    }
  }
}
