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
 * - **RUM Configuration**: AWS region, app monitor ID, and endpoint overrides
 * - **Application Metadata**: Version information and application identification
 * - **Telemetry Features**: Control over automatic instrumentation capabilities
 * - **Schema Versioning**: Configuration format version for compatibility
 *
 */
@objc public class AwsOpenTelemetryConfig: NSObject, Codable {
  /// Schema version of the configuration
  public var version: String?

  /// RUM (Real User Monitoring) configuration settings
  public var rum: RumConfig

  /// Application-specific configuration settings
  public var application: ApplicationConfig

  /// Telemetry feature configuration settings
  public var telemetry: TelemetryConfig?

  /**
   * Initializes a new configuration instance.
   *
   * @param version The schema version of the configuration (defaults to "1.0.0")
   * @param rum The RUM configuration settings
   * @param application The application configuration settings
   * @param telemetry The telemetry configuration settings (defaults to enabled features)
   */
  @objc public init(version: String? = "1.0.0",
                    rum: RumConfig,
                    application: ApplicationConfig,
                    telemetry: TelemetryConfig? = TelemetryConfig()) {
    self.version = version
    self.rum = rum
    self.application = application
    self.telemetry = telemetry
    super.init()
  }
}

/**
 * Configuration for AWS CloudWatch RUM (Real User Monitoring) service integration.
 *
 * This class contains all settings required to connect your application to AWS CloudWatch RUM,
 * including service endpoints, authentication parameters, and debugging options.
 *
 * ## Required Settings
 *
 * - **region**: The AWS region where your RUM App Monitor is deployed
 * - **appMonitorId**: The unique identifier of your RUM App Monitor
 *
 * ## Optional Settings
 *
 * - **overrideEndpoint**: Custom endpoints for traces and logs (useful for testing)
 * - **debug**: Enable verbose logging for troubleshooting SDK integration
 * - **alias**: Additional identifier for request routing and access control
 *
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

  // The user session will expire if inactive for the specified length (default 30 minutes)
  public var sessionLength: Double?

  /**
   * Initializes a new RUM configuration instance.
   *
   * @param region AWS region where the RUM service is deployed
   * @param appMonitorId Unique identifier for the RUM App Monitor
   * @param overrideEndpoint Optional endpoint overrides for the RUM service
   * @param debug Flag to enable debug logging (defaults to false)
   */
  @objc public init(region: String,
                    appMonitorId: String,
                    overrideEndpoint: EndpointOverrides? = nil,
                    debug: Bool = false,
                    alias: String? = nil,
                    sessionLength: NSNumber? = nil) {
    self.region = region
    self.appMonitorId = appMonitorId
    self.overrideEndpoint = overrideEndpoint
    self.debug = debug
    self.alias = alias
    self.sessionLength = (sessionLength as? Double) ?? AwsSessionManager.defaultSessionLength
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

/**
 * Configuration for controlling automatic telemetry instrumentation features.
 *
 * This class allows you to enable or disable specific automatic instrumentation
 * capabilities provided by the AWS OpenTelemetry SDK. Each feature can be
 * controlled independently to match your application's requirements.
 *
 * ## Available Features
 *
 * - **UIKit View Instrumentation**: Automatically creates spans for view controller
 *   lifecycle events (viewDidLoad, viewWillAppear, viewDidAppear, etc.)
 *
 * ## Default Behavior
 *
 * By default, all instrumentation features are **enabled** to provide comprehensive
 * observability out of the box. You can selectively disable features if needed.
 *
 */
@objc public class TelemetryConfig: NSObject, Codable {
  /// Enable UIKit view instrumentation (default: true)
  @objc public var isUiKitViewInstrumentationEnabled: Bool

  /**
   * Initializes telemetry configuration with default values.
   */
  @objc override public init() {
    isUiKitViewInstrumentationEnabled = true
    super.init()
  }

  /**
   * Initializes telemetry configuration with custom values.
   *
   * @param isUiKitViewInstrumentationEnabled Enable UIKit view instrumentation
   */
  @objc public init(isUiKitViewInstrumentationEnabled: Bool) {
    self.isUiKitViewInstrumentationEnabled = isUiKitViewInstrumentationEnabled
    super.init()
  }
}
