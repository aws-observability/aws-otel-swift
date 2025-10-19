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

protocol HangReporter {
  func start(hangThreshold: TimeInterval)
  func stop()
}

class RunLoopHangReporter: HangReporter {
  private var lastActivity: Date = .init()
  private var hangThreshold: TimeInterval = 0.25
  private let tracer: Tracer

  init() {
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsInstrumentationScopes.RUNLOOP_HANG_REPORTER)
  }

  func start(hangThreshold: TimeInterval) {
    self.hangThreshold = hangThreshold
    setupRunLoopObserver()
  }

  func stop() {
    // RunLoop observer cleanup is handled automatically
  }

  private func setupRunLoopObserver() {
    AwsOpenTelemetryLogger.debug("RunLoopHangReporter: Setting up RunLoop observer")
    let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.afterWaiting.rawValue, true, 0) { [weak self] _, activity in
      guard let self else { return }

      let now = Date()

      if activity == CFRunLoopActivity.afterWaiting {
        lastActivity = now
      } else if activity == CFRunLoopActivity.beforeWaiting {
        let hangDuration = now.timeIntervalSince(lastActivity)

        if hangDuration >= 0.05 { // 50 ms
          AwsOpenTelemetryLogger.debug("RunLoopHangReporter: RunLoop entered beforeWaiting, duration: \(Int(hangDuration * 1000))ms")
        }

        if hangDuration >= hangThreshold {
          AwsOpenTelemetryLogger.debug("RunLoopHangReporter: CFRunLoop detected hang of \(Int(hangDuration * 1000))ms")
          reportHang(startTime: lastActivity, endTime: now, duration: hangDuration)
        }
      }
    }

    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
  }

  private func reportHang(startTime: Date, endTime: Date, duration: TimeInterval) {
    let span = tracer.spanBuilder(spanName: "device.hang")
      .setStartTime(time: startTime)
      .startSpan()
    span.end(time: endTime)
  }
}
