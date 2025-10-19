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

class PingHangReporter: HangReporter {
  private var watchdogTimer: Timer?
  private var lastPing: Date = .init()
  private var hangThreshold: TimeInterval = 0.25
  private let watchdogQueue = DispatchQueue(label: "ping.hang.watchdog", qos: .userInitiated)
  private var isRunning = false
  private let tracer: Tracer

  init() {
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsInstrumentationScopes.PING_HANG_REPORTER)
  }

  func start(hangThreshold: TimeInterval) {
    self.hangThreshold = hangThreshold
    isRunning = true

    DispatchQueue.main.async {
      self.startMainThreadPing()
    }

    watchdogQueue.async {
      self.startBackgroundMonitoring()
    }
  }

  func stop() {
    isRunning = false
    watchdogTimer?.invalidate()
    watchdogTimer = nil
  }

  private func startMainThreadPing() {
    AwsOpenTelemetryLogger.debug("PingHangReporter: Starting main thread ping")
    watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.lastPing = Date()
    }
  }

  private func startBackgroundMonitoring() {
    AwsOpenTelemetryLogger.debug("PingHangReporter: Starting background monitoring")

    while isRunning {
      Thread.sleep(forTimeInterval: 0.1)

      let now = Date()
      let timeSinceLastPing = now.timeIntervalSince(lastPing)

      if timeSinceLastPing >= hangThreshold {
        let hangStart = Date(timeIntervalSince1970: lastPing.timeIntervalSince1970)
        AwsOpenTelemetryLogger.debug("PingHangReporter: Ping detected hang of \(Int(timeSinceLastPing * 1000))ms")

        // Wait for main thread to recover
        while Date().timeIntervalSince(lastPing) >= hangThreshold, isRunning {
          Thread.sleep(forTimeInterval: 0.05)
        }

        // Report hang with actual recovery time
        let recoveryTime = Date()
        let actualDuration = recoveryTime.timeIntervalSince(hangStart)
        reportHang(startTime: hangStart, endTime: recoveryTime, duration: actualDuration)
      }
    }
  }

  private func reportHang(startTime: Date, endTime: Date, duration: TimeInterval) {
    DispatchQueue.main.async {
      let span = self.tracer.spanBuilder(spanName: "device.hang")
        .setStartTime(time: startTime)
        .startSpan()
      span.end(time: endTime)
    }
  }
}
