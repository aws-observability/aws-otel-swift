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
 * Configuration model for AWS OpenTelemetry SDK.
 *
 * This class defines the structure for configuring the AWS OpenTelemetry SDK,
 * including RUM (Real User Monitoring) settings and application information.
 */
@objc public class AwsOpenTelemetryConfig: NSObject, Codable {
  /// Schema version of the configuration
  public var version: String?

  /// RUM (Real User Monitoring) configuration settings
  public var rum: RumConfig

  /// Application-specific configuration settings
  public var application: ApplicationConfig

  /**
   * Initializes a new configuration instance.
   *
   * @param version The schema version of the configuration (defaults to "1.0.0")
   * @param rum The RUM configuration settings
   * @param application The application configuration settings
   */
  @objc public init(version: String? = "1.0.0",
                    rum: RumConfig,
                    application: ApplicationConfig) {
    self.version = version
    self.rum = rum
    self.application = application
    super.init()
  }
}

/**
 * Configuration for AWS RUM (Real User Monitoring).
 *
 * Contains settings specific to the AWS RUM service, including region,
 * app monitor identifier, and optional configuration overrides.
 */
@objc public class RumConfig: NSObject, Codable {
  /// AWS region where the RUM service is deployed
  public var region: String

  /// Unique identifier for the RUM App Monitor
  public var appMonitorId: String

  /// Optional endpoint overrides for the RUM service
  public var overrideEndpoint: EndpointOverrides?

  /// Flag to enable debug logging for SDK integration
  public var debug: Bool?
    
  /// Optional alias to add to all requests to compare against the rum:alias
  ///  in appmonitors with resource based policies
  public var alias: String?

  /**
   * Initializes a new RUM configuration instance.
   *
   * @param region AWS region where the RUM service is deployed
   * @param appMonitorId Unique identifier for the RUM App Monitor
   * @param overrideEndpoint Optional endpoint overrides for the RUM service
   * @param debug Flag to enable debug logging (defaults to false)
   */
  @objc public init(region: String, appMonitorId: String, overrideEndpoint: EndpointOverrides? = nil, debug: Bool = false, alias: String? = nil,) {
    self.region = region
    self.appMonitorId = appMonitorId
    self.overrideEndpoint = overrideEndpoint
    self.debug = debug
    self.alias = alias
    super.init()
  }
}

/**
 * Configuration for endpoint overrides.
 *
 * Allows customization of the endpoints used for logs and traces,
 * which is useful for testing or custom deployments.
 */
@objc public class EndpointOverrides: NSObject, Codable {
  /// Custom endpoint URL for logs
  public var logs: String?

  /// Custom endpoint URL for traces
  public var traces: String?

  /**
   * Initializes a new endpoint overrides instance.
   *
   * @param logs Custom endpoint URL for logs
   * @param traces Custom endpoint URL for traces
   */
  @objc public init(logs: String? = nil, traces: String? = nil) {
    self.logs = logs
    self.traces = traces
    super.init()
  }
}

/**
 * Configuration for application-specific settings.
 *
 * Contains metadata about the application being monitored.
 */
@objc public class ApplicationConfig: NSObject, Codable {
  /// Version of the application being monitored
  public var applicationVersion: String

  /**
   * Initializes a new application configuration instance.
   *
   * @param applicationVersion Version of the application being monitored
   */
  @objc public init(applicationVersion: String) {
    self.applicationVersion = applicationVersion
    super.init()
  }
}
