import Foundation
import CrashReporter

public struct StackTrace {
  let message: String
  let stacktrace: String
}

public protocol StackTraceCollector {
  var maxStackTraceLength: Int { get }
  func generateLiveStackTrace() -> Data?
  func formatStackTrace(rawStackTrace: Data) -> StackTrace
  init(maxStackTraceLength: Int)
}

public class PLStackTraceCollector: StackTraceCollector {
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
        AwsInternalLogger.error("PLStackTraceCollector: Failed to format crash report to string")
      }
    } catch {
      AwsInternalLogger.error("PLStackTraceCollector: Failed to parse crash report: \(error)")
      stacktrace = "Failed to parse stack trace: \(error)"
    }
    return StackTrace(message: message, stacktrace: stacktrace)
  }

  func getFirstFrameOfMain(stacktrace: String) -> String? {
    return stacktrace.components(separatedBy: "Thread 0:\n0").dropFirst().first?.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
  }
}
