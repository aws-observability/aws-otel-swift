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
import KSCrashRecordingCore

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

public class KSCrashLiveStackTraceReporter: LiveStackTraceReporter {
  public let maxStackTraceLength: Int
  private let maxFrames = 128
  private var targetThread: pthread_t?

  public required init(maxStackTraceLength: Int = 10 * 1000) {
    self.maxStackTraceLength = maxStackTraceLength
  }

  public func setTargetThread(_ thread: pthread_t) {
    targetThread = thread
  }

  public func generateLiveStackTrace() -> Data? {
    guard let thread = targetThread else {
      return nil
    }
    var addresses = [UInt](repeating: 0, count: maxFrames)
    let count = captureBacktrace(thread: thread, addresses: &addresses, count: Int32(maxFrames))
    guard count > 0 else {
      return nil
    }
    let captured = Array(addresses.prefix(Int(count)))
    return try? JSONEncoder().encode(captured)
  }

  public func formatStackTrace(rawStackTrace: Data) -> StackTrace {
    guard let addresses = try? JSONDecoder().decode([UInt].self, from: rawStackTrace), !addresses.isEmpty else {
      return StackTrace(message: "Hang detected at unknown location", stacktrace: "Failed to parse stack trace")
    }

    var lines: [String] = []
    var firstFrameDescription: String?

    for (index, address) in addresses.enumerated() {
      var info = SymbolInformation()
      let success = symbolicate(address: address, result: &info)

      let line: String
      if success {
        let imageName = info.imageName.map { String(cString: $0).components(separatedBy: "/").last ?? String(cString: $0) } ?? "???"
        let symbolName = info.symbolName.map { String(cString: $0) } ?? "0x\(String(address, radix: 16))"
        let offset = address - info.symbolAddress
        line = "\(index)\t\(imageName)\t\(symbolName) + \(offset)"

        if index == 0 {
          firstFrameDescription = "\(imageName) + \(offset)"
        }
      } else {
        line = "\(index)\t???\t0x\(String(address, radix: 16))"
      }
      lines.append(line)
    }

    let fullTrace = "Thread 0:\n" + lines.joined(separator: "\n")
    let stacktrace = String(fullTrace.prefix(maxStackTraceLength))
    let message = "Hang detected at \(firstFrameDescription ?? "unknown location")"
    return StackTrace(message: message, stacktrace: stacktrace)
  }
}

/// Noop implementation for platforms where live stack trace collection is unavailable
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
