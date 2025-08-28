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

/// Configuration object for MetricKit integration settings.
///
/// Controls MetricKit behavior including crash diagnostics collection.
///
/// Example:
/// ```swift
/// // Direct initialization
/// let config = AwsMetricKitConfig(crashes: false)
///
/// // Using builder pattern
/// let config = AwsMetricKitConfig.builder()
///   .with(crashes: false)
///   .build()
/// ```
public struct AwsMetricKitConfig {
  /// Whether to collect crash diagnostics from MetricKit
  public let crashes: Bool

  /// Creates a new MetricKit configuration
  /// - Parameter crashes: Whether to collect crash diagnostics (default true)
  public init(crashes: Bool = true) {
    self.crashes = crashes
  }

  /// Default configuration with crash collection enabled
  public static let `default` = AwsMetricKitConfig()
}

/// Builder for creating AwsMetricKitConfig instances with a fluent API.
///
/// Provides a convenient way to configure MetricKit settings using method chaining.
///
/// Example:
/// ```swift
/// let config = AwsMetricKitConfig.builder()
///   .with(crashes: false)
///   .build()
/// ```
public class AwsMetricKitConfigBuilder {
  public private(set) var crashes: Bool = true
  public private(set) var hangs: Bool = true
  
  public init() {}

  /// Sets whether to collect crash diagnostics
  /// - Parameter crashes: Whether to collect crash diagnostics from MetricKit
  /// - Returns: The builder instance for method chaining
  public func with(crashes: Bool) -> Self {
    self.crashes = crashes
    return self
  }
  
  /// Sets whether to collect crash diagnostics
  /// - Parameter crashes: Whether to collect crash diagnostics from MetricKit
  /// - Returns: The builder instance for method chaining
  public func with(hangs: Bool) -> Self {
    self.hangs = hangs
    return self
  }

  /// Builds the AwsMetricKitConfig with the configured settings
  /// - Returns: A new AwsMetricKitConfig instance
  public func build() -> AwsMetricKitConfig {
    return AwsMetricKitConfig(crashes: crashes)
  }
}

/// Extension to AwsMetricKitConfig for builder pattern support
public extension AwsMetricKitConfig {
  /// Creates a new AwsMetricKitConfigBuilder instance
  /// - Returns: A new builder for creating AwsMetricKitConfig
  static func builder() -> AwsMetricKitConfigBuilder {
    return AwsMetricKitConfigBuilder()
  }
}
