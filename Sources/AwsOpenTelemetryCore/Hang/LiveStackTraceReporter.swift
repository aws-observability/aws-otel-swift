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
#if !os(watchOS)
  import CrashReporter
#endif

public struct StackTrace {
  let message: String
  let stacktrace: String
}

public protocol LiveStackTraceReporter {
  var maxStackTraceLength: Int { get }
  func generateLiveStackTrace() -> Data?
  func formatStackTrace(rawStackTrace: Data) -> StackTrace
  init(maxStackTraceLength: Int)
}

#if !os(watchOS)
  public class PLLiveStackTraceReporter: LiveStackTraceReporter {
    let reporter: PLCrashReporter
    public let maxStackTraceLength: Int

    public required init(maxStackTraceLength: Int = 10 * 1000) {
      self.maxStackTraceLength = maxStackTraceLength
      let config = PLCrashReporterConfig(
        signalHandlerType: .BSD,
        symbolicationStrategy: [] // empty list means no symbolication, and implies a ~20 ms fetch time
        // To get on-device symbolication during development, set symbolicationStrategy to
        // - `.all` (2 sec blocking delay)
        // - `.symbolTable` (1 sec blocking delay)
      )
      // PLCrashReporter is designed for crash reports but we are able to take advantage of its live report feature,
      // which is perfect for collecting stack traces associated with app hangs. This does not interfere with other
      // crash reporters because we are not using the crash report feature.
      reporter = PLCrashReporter(configuration: config)
    }

    public func generateLiveStackTrace() -> Data? {
      return reporter.generateLiveReport()
    }

    public func formatStackTrace(rawStackTrace: Data) -> StackTrace {
      var stacktrace = "Failed to collect stack trace"
      var message = "Hang detected on main thread at unknown location"
      do {
        let crashReport = try PLCrashReport(data: rawStackTrace)
        if let fullStacktrace = PLCrashReportTextFormatter.stringValue(for: crashReport, with: PLCrashReportTextFormatiOS) {
          stacktrace = String(fullStacktrace.prefix(maxStackTraceLength))
          let firstFrame = getFirstFrameOfMain(stacktrace: stacktrace) ?? "unknown location"
          message = "Hang detected on main thread at \(firstFrame)"
        } else {
          AwsInternalLogger.error("PLLiveStackTraceReporter: Failed to format crash report to string")
        }
      } catch {
        AwsInternalLogger.error("PLLiveStackTraceReporter: Failed to parse crash report: \(error)")
        stacktrace = "Failed to parse stack trace: \(error)"
      }
      return StackTrace(message: message, stacktrace: stacktrace)
    }

    func getFirstFrameOfMain(stacktrace: String) -> String? {
      return stacktrace.components(separatedBy: "Thread 0:\n0").dropFirst().first?.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
  }
#endif

// Noop implementation for platforms where PLCrashReporter is not available
public class NoopLiveStackTraceReporter: LiveStackTraceReporter {
  public let maxStackTraceLength: Int

  public required init(maxStackTraceLength: Int = 10 * 1000) {
    self.maxStackTraceLength = maxStackTraceLength
  }

  public func generateLiveStackTrace() -> Data? {
    return nil
  }

  public func formatStackTrace(rawStackTrace: Data) -> StackTrace {
    return StackTrace(message: "Stack trace collection not available", stacktrace: "Stack trace collection not supported on this platform")
  }
}
