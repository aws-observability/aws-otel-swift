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

/// Centralized logging utility for AWS OpenTelemetry SDK that respects debug configuration
public enum AwsOpenTelemetryLogger {
  /// Logs a debug message if debug mode is enabled
  /// - Parameter message: The message to log
  public static func debug(_ message: String) {
    guard isDebugEnabled else { return }
    print("[AwsOpenTelemetry] DEBUG: \(message)")
  }

  /// Logs an error message
  /// - Parameter message: The error message to log
  public static func error(_ message: String) {
    print("[AwsOpenTelemetry] ERROR: \(message)")
  }

  /// Logs an info message if debug mode is enabled
  /// - Parameter message: The info message to log
  public static func info(_ message: String) {
    guard isDebugEnabled else { return }
    print("[AwsOpenTelemetry] INFO: \(message)")
  }

  /// Checks if debug logging is enabled based on the current configuration
  private static var isDebugEnabled: Bool {
    return AwsOpenTelemetryAgent.shared.configuration?.rum.debug ?? false
  }
}
