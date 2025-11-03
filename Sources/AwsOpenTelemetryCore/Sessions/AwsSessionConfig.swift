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
/// // Direct initialization
/// let config = AwsSessionConfig(sessionTimeout: 45 * 60) // 45 minutes
///
/// // Using builder pattern
/// let config = AwsSessionConfig.builder()
///   .with(sessionTimeout: 45 * 60)
///   .build()
///
/// let manager = AwsSessionManager(configuration: config)
/// ```
public struct AwsSessionConfig {
  /// Duration in seconds after which a session expires if left inactive
  public let sessionTimeout: Int
  /// Session sample rate (0.0 to 1.0)
  public let sessionSampleRate: Double

  /// Creates a new session configuration
  /// - Parameter sessionTimeout: Duration in seconds after which a session expires if left inactive (default 30 minutes)
  /// - Parameter sessionSampleRate: Session sample rate from 0.0 to 1.0 (default 1.0)
  public init(sessionTimeout: Int = 30 * 60, sessionSampleRate: Double = 1.0) {
    self.sessionTimeout = sessionTimeout
    self.sessionSampleRate = sessionSampleRate
  }

  /// Default configuration with 30-minute session timeout
  public static let `default` = AwsSessionConfig()
}

/// Builder for creating AwsSessionConfig instances with a fluent API.
///
/// Provides a convenient way to configure session settings using method chaining.
///
/// Example:
/// ```swift
/// let config = AwsSessionConfig.builder()
///   .with(sessionTimeout: 45 * 60)
///   .build()
/// ```
public class AwsSessionConfigBuilder {
  public private(set) var sessionTimeout: Int = 30 * 60
  public private(set) var sessionSampleRate: Double = 1.0

  public init() {}

  /// Sets the session timeout duration
  /// - Parameter sessionTimeout: Duration in seconds after which a session expires if left inactive
  /// - Returns: The builder instance for method chaining
  public func with(sessionTimeout: Int) -> Self {
    self.sessionTimeout = sessionTimeout
    return self
  }

  /// Sets the session sample rate
  /// - Parameter sessionSampleRate: Session sample rate from 0.0 to 1.0
  /// - Returns: The builder instance for method chaining
  public func with(sessionSampleRate: Double) -> Self {
    self.sessionSampleRate = sessionSampleRate
    return self
  }

  /// Builds the AwsSessionConfig with the configured settings
  /// - Returns: A new AwsSessionConfig instance
  public func build() -> AwsSessionConfig {
    return AwsSessionConfig(sessionTimeout: sessionTimeout, sessionSampleRate: sessionSampleRate)
  }
}

/// Extension to AwsSessionConfig for builder pattern support
public extension AwsSessionConfig {
  /// Creates a new AwsSessionConfigBuilder instance
  /// - Returns: A new builder for creating AwsSessionConfig
  static func builder() -> AwsSessionConfigBuilder {
    return AwsSessionConfigBuilder()
  }
}
