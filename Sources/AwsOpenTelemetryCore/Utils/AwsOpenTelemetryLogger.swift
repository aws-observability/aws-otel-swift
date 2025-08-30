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
import os.log

/// Centralized logging utility for AWS OpenTelemetry SDK that respects debug configuration
public enum AwsOpenTelemetryLogger {
  /// Log level types
  private enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func log(logger: Logger, message: String) {
      switch self {
      case .debug:
        logger.debug("\(message)")
      case .info:
        logger.info("\(message)")
      case .warning:
        logger.warning("\(message)")
      case .error:
        logger.error("\(message)")
      }
    }
  }

  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.amazon.aws-otel-swift"
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  private static let logger = Logger(subsystem: subsystem, category: "AwsOpenTelemetry")

  /// Logs a debug message if debug mode is enabled
  /// - Parameters:
  ///   - message: The message to log
  ///   - file: Source file (automatically captured)
  ///   - function: Function name (automatically captured)
  ///   - line: Line number (automatically captured)
  public static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    log(.debug, message: message, file: file, function: function, line: line, requiresDebugMode: true)
  }

  /// Logs an error message
  /// - Parameters:
  ///   - message: The error message to log
  ///   - file: Source file (automatically captured)
  ///   - function: Function name (automatically captured)
  ///   - line: Line number (automatically captured)
  public static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    log(.error, message: message, file: file, function: function, line: line, requiresDebugMode: false)
  }

  /// Logs an info message if debug mode is enabled
  /// - Parameters:
  ///   - message: The info message to log
  ///   - file: Source file (automatically captured)
  ///   - function: Function name (automatically captured)
  ///   - line: Line number (automatically captured)
  public static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    log(.info, message: message, file: file, function: function, line: line, requiresDebugMode: true)
  }

  /// Logs a warning message if debug mode is enabled
  /// - Parameters:
  ///   - message: The warning message to log
  ///   - file: Source file (automatically captured)
  ///   - function: Function name (automatically captured)
  ///   - line: Line number (automatically captured)
  public static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    log(.warning, message: message, file: file, function: function, line: line, requiresDebugMode: true)
  }

  /// Centralizes logging logic for all log levels
  /// - Parameters:
  ///   - level: The log level
  ///   - message: The message to log
  ///   - file: Source file
  ///   - function: Function name
  ///   - line: Line number
  ///   - requiresDebugMode: Whether this log level requires debug mode to be enabled
  private static func log(_ level: LogLevel,
                          message: String,
                          file: String,
                          function: String,
                          line: Int,
                          requiresDebugMode: Bool) {
    if requiresDebugMode, !isDebugEnabled {
      return
    }

    let formattedMessage = formatMessage(message, file: file, function: function, line: line)

    if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
      level.log(logger: logger, message: formattedMessage)
    } else {
      print("[\(level.rawValue)] \(formattedMessage)")
    }
  }

  /// Formats the log message consistently
  /// - Parameters:
  ///   - message: The message to format
  ///   - file: Source file
  ///   - function: Function name
  ///   - line: Line number
  /// - Returns: A consistently formatted log message
  private static func formatMessage(_ message: String, file: String, function: String, line: Int) -> String {
    let fileName = (file as NSString).lastPathComponent
    return "\(fileName):\(line) \(function) - \(message)"
  }

  /// Checks if debug logging is enabled based on the current configuration
  private static var isDebugEnabled: Bool {
    return AwsOpenTelemetryAgent.shared.configuration?.debug ?? false
  }
}
