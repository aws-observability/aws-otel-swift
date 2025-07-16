/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Configuration object for session management settings.
///
/// Controls session behavior including timeout duration and expiration handling.
/// Sessions automatically expire after the specified timeout period of inactivity.
///
/// Example:
/// ```swift
/// let config = SessionConfiguration(sessionTimeout: 45 * 60) // 45 minutes
/// let manager = SessionManager(configuration: config)
/// ```
public struct AwsSessionConfiguration {
  /// Duration in seconds after which a session expires if left inactive
  public let sessionTimeout: Int

  /// Creates a new session configuration
  /// - Parameter sessionTimeout: Duration in seconds after which a session expires if left inactive (default 30 minutes)
  public init(sessionTimeout: Int = 30 * 60) {
    self.sessionTimeout = sessionTimeout
  }

  /// Default configuration with 30-minute session timeout
  public static let `default` = AwsSessionConfiguration()
}
