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

/// Instrumentation for detecting and reporting application hangs
public class HangInstrumentation {
  private let hangThreshold: TimeInterval = 0.25 // 250ms
  private let runLoopReporter = RunLoopHangReporter()
  // private let pingReporter = PingHangReporter()

  static let shared = HangInstrumentation()

  public init() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Initializing")
    startReporters()
  }

  deinit {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Deinitializing")
    stopReporters()
  }

  private func startReporters() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Starting reporters")

    DispatchQueue.main.async {
      self.runLoopReporter.start(hangThreshold: self.hangThreshold)
    }

    // pingReporter.start(hangThreshold: hangThreshold)
  }

  private func stopReporters() {
    AwsOpenTelemetryLogger.debug("HangInstrumentation: Stopping reporters")
    runLoopReporter.stop()
    // pingReporter.stop()
  }
}
