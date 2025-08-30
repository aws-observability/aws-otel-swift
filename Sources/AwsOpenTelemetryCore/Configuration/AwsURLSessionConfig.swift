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

/// Configuration object for AWS URLSession instrumentation settings.
///
/// Controls URLSession instrumentation behavior including endpoint exclusions
/// to prevent recursive instrumentation of telemetry endpoints.
///
/// Example:
/// ```swift
/// // Direct initialization
/// let config = AwsURLSessionConfig(region: "us-west-2")
///
/// // Using builder pattern
/// let config = AwsURLSessionConfig.builder()
///   .with(region: "us-west-2")
///   .with(exportOverride: ExportOverride(traces: "https://custom-traces.example.com"))
///   .build()
///
/// let instrumentation = AwsURLSessionInstrumentation(config: config)
/// ```
public struct AwsURLSessionConfig {
  /// AWS region for building default RUM endpoints
  public let region: String

  /// Optional export overrides for custom telemetry endpoints
  public let exportOverride: ExportOverride?

  /// Creates a new URLSession instrumentation configuration
  /// - Parameters:
  ///   - region: AWS region for building default RUM endpoints
  ///   - exportOverride: Optional export overrides for custom telemetry endpoints
  public init(region: String, exportOverride: ExportOverride? = nil) {
    self.region = region
    self.exportOverride = exportOverride
  }
}

/// Builder for creating AwsURLSessionConfig instances with a fluent API.
///
/// Provides a convenient way to configure URLSession instrumentation settings using method chaining.
///
/// Example:
/// ```swift
/// let config = AwsURLSessionConfig.builder()
///   .with(region: "us-west-2")
///   .with(exportOverride: ExportOverride(traces: "https://custom-traces.example.com"))
///   .build()
/// ```
public class AwsURLSessionConfigBuilder {
  public private(set) var region: String?
  public private(set) var exportOverride: ExportOverride?

  public init() {}

  /// Sets the AWS region
  /// - Parameter region: AWS region for building default RUM endpoints
  /// - Returns: The builder instance for method chaining
  public func with(region: String) -> Self {
    self.region = region
    return self
  }

  /// Sets the export override configuration
  /// - Parameter exportOverride: Optional export overrides for custom telemetry endpoints
  /// - Returns: The builder instance for method chaining
  public func with(exportOverride: ExportOverride?) -> Self {
    self.exportOverride = exportOverride
    return self
  }

  /// Builds the AwsURLSessionConfig with the configured settings
  /// - Returns: A new AwsURLSessionConfig instance
  /// - Throws: Precondition failure if required region is not set
  public func build() -> AwsURLSessionConfig {
    guard let region else {
      preconditionFailure("Region is required for AwsURLSessionConfig")
    }
    return AwsURLSessionConfig(region: region, exportOverride: exportOverride)
  }
}

/// Extension to AwsURLSessionConfig for builder pattern support
public extension AwsURLSessionConfig {
  /// Creates a new AwsURLSessionConfigBuilder instance
  /// - Returns: A new builder for creating AwsURLSessionConfig
  static func builder() -> AwsURLSessionConfigBuilder {
    return AwsURLSessionConfigBuilder()
  }
}
