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
