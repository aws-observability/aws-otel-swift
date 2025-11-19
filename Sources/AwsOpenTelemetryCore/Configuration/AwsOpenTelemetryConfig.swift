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

/**
 * Root configuration object for the AWS OpenTelemetry SDK.
 *
 * This class serves as the main configuration container for initializing the AWS OpenTelemetry SDK
 * with Real User Monitoring (RUM) capabilities. It encompasses all necessary settings for:
 *
 * - **AWS Configuration**: Region, RUM app monitor ID, and Cognito identity pool
 * - **Export Overrides**: Custom endpoints for logs and traces
 * - **Session Configuration**: Timeout settings
 * - **Application Attributes**: Key-value pairs for application metadata
 * - **Telemetry Features**: Control over automatic instrumentation capabilities
 *
 */
@objc public class AwsOpenTelemetryConfig: NSObject, Codable {
  /// AWS service configuration settings
  public var aws: AwsConfig

  /// Export endpoint overrides
  public var exportOverride: AwsExportOverride?

  /// Session timeout in seconds
  public var sessionTimeout: Int?

  /// Session sample rate (0.0 to 1.0)
  public var sessionSampleRate: Double?

  /// Application attributes
  public var applicationAttributes: [String: String]?

  /// Debug flag
  public var debug: Bool?

  /// Telemetry feature configuration settings
  public var telemetry: AwsTelemetryConfig?

  /// Custom X-Forwarded-For header value (optional)
  public var xForwardedFor: String?

  /**
   * Initializes a new configuration instance.
   *
   * @param aws AWS service configuration
   * @param exportOverride Optional export endpoint overrides
   * @param sessionTimeout Session timeout in seconds
   * @param sessionSampleRate Session sample rate (0.0 to 1.0)
   * @param applicationAttributes Application metadata attributes
   * @param debug Debug logging flag
   * @param telemetry Telemetry configuration (defaults to all enabled)
   */
  public init(aws: AwsConfig,
              exportOverride: AwsExportOverride? = nil,
              sessionTimeout: Int? = nil,
              sessionSampleRate: Double? = nil,
              applicationAttributes: [String: String]? = nil,
              debug: Bool? = nil,
              telemetry: AwsTelemetryConfig? = AwsTelemetryConfig(),
              xForwardedFor: String? = nil) {
    self.aws = aws
    self.exportOverride = exportOverride
    self.sessionTimeout = sessionTimeout
    self.sessionSampleRate = sessionSampleRate
    self.applicationAttributes = applicationAttributes
    self.debug = debug
    self.telemetry = telemetry
    self.xForwardedFor = xForwardedFor
    super.init()
  }

  /// Creates a new AwsOpenTelemetryConfigBuilder instance
  static func builder() -> AwsOpenTelemetryConfigBuilder {
    return AwsOpenTelemetryConfigBuilder()
  }

  // Custom decoder implementation to handle default values
  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    aws = try container.decode(AwsConfig.self, forKey: .aws)
    exportOverride = try container.decodeIfPresent(AwsExportOverride.self, forKey: .exportOverride)
    sessionTimeout = try container.decodeIfPresent(Int.self, forKey: .sessionTimeout)
    sessionSampleRate = try container.decodeIfPresent(Double.self, forKey: .sessionSampleRate)
    applicationAttributes = try container.decodeIfPresent([String: String].self, forKey: .applicationAttributes)
    debug = try container.decodeIfPresent(Bool.self, forKey: .debug)
    telemetry = try container.decodeIfPresent(AwsTelemetryConfig.self, forKey: .telemetry) ?? AwsTelemetryConfig()
    super.init()
  }
}

/// Builder for creating AwsOpenTelemetryConfig instances with a fluent API
public class AwsOpenTelemetryConfigBuilder {
  public private(set) var aws: AwsConfig?
  public private(set) var exportOverride: AwsExportOverride?
  public private(set) var sessionTimeout: Int?
  public private(set) var sessionSampleRate: Double?
  public private(set) var applicationAttributes: [String: String]?
  public private(set) var debug: Bool?
  public private(set) var telemetry: AwsTelemetryConfig? = AwsTelemetryConfig()

  public init() {}

  /// Sets the AWS configuration
  public func with(aws: AwsConfig) -> Self {
    self.aws = aws
    return self
  }

  /// Sets the export override configuration
  public func with(exportOverride: AwsExportOverride?) -> Self {
    self.exportOverride = exportOverride
    return self
  }

  /// Sets the session timeout
  public func with(sessionTimeout: Int?) -> Self {
    self.sessionTimeout = sessionTimeout
    return self
  }

  /// Sets the session sample rate
  public func with(sessionSampleRate: Double?) -> Self {
    self.sessionSampleRate = sessionSampleRate
    return self
  }

  /// Sets the application attributes
  public func with(applicationAttributes: [String: String]?) -> Self {
    self.applicationAttributes = applicationAttributes
    return self
  }

  /// Sets the debug flag
  public func with(debug: Bool?) -> Self {
    self.debug = debug
    return self
  }

  /// Sets the telemetry configuration
  public func with(telemetry: AwsTelemetryConfig?) -> Self {
    self.telemetry = telemetry
    return self
  }

  /// Builds the AwsOpenTelemetryConfig with the configured settings
  public func build() -> AwsOpenTelemetryConfig {
    guard let aws else {
      fatalError("AwsOpenTelemetryConfig requires aws configuration to be set")
    }
    return AwsOpenTelemetryConfig(
      aws: aws,
      exportOverride: exportOverride,
      sessionTimeout: sessionTimeout,
      sessionSampleRate: sessionSampleRate,
      applicationAttributes: applicationAttributes,
      debug: debug,
      telemetry: telemetry
    )
  }
}
