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
import OpenTelemetryApi

/**
 * The central agent for AWS OpenTelemetry SDK initialization and management.
 *
 * This singleton class provides the main entry point for initializing the AWS OpenTelemetry SDK
 * with RUM (Real User Monitoring) capabilities. It manages the SDK lifecycle and provides
 * access to instrumentation components.
 *
 * The agent is typically initialized automatically when using `AwsOpenTelemetryAgent` module,
 * or manually using `AwsOpenTelemetryRumBuilder`:
 *
 * This class is thread-safe and can be accessed from multiple threads concurrently.
 * However, initialization should only be performed once during the application lifecycle.
 * If done more than once, only the first initialization will be successful.
 */
@objc public class AwsOpenTelemetryAgent: NSObject {
  /// The instrumentation name used to identify this AWS OpenTelemetry Swift SDK
  /// when creating tracers and other telemetry components
  static let name = "aws-otel-swift"

  /// The version of the AWS OpenTelemetry Swift SDK instrumentation
  /// This is automatically managed by scripts/bump-version.sh
  static let version = "0.0.0"

  /// Shared singleton instance for global access to the AWS OpenTelemetry agent
  @objc public static let shared = AwsOpenTelemetryAgent()

  /// The current active configuration used to initialize the SDK
  /// This is set during initialization and remains immutable afterwards
  public internal(set) var configuration: AwsOpenTelemetryConfig?

  /// Flag indicating whether the SDK has been successfully initialized
  /// Once set to true, subsequent initialization attempts will be ignored
  @objc public internal(set) var isInitialized: Bool = false

  #if canImport(UIKit) && !os(watchOS)
    /// UIKit view instrumentation for automatic view controller lifecycle tracking
    /// This is created when UIKit instrumentation is enabled in the telemetry configuration
    /// and provides automatic span creation for view controller lifecycle events
    public internal(set) var uiKitViewInstrumentation: UIKitViewInstrumentation?
  #endif

  #if canImport(MetricKit) && !os(tvOS) && !os(macOS)
    public internal(set) var metricKitSubscriber: Any? // Any? to prevent compile time error to `AwsMetricKitSubscriber`
  #endif

  /// Private initializer to enforce singleton pattern
  /// Use `AwsOpenTelemetryAgent.shared` to access the singleton instance
  override private init() {
    super.init()
  }

  /**
   * Initializes the AWS OpenTelemetry SDK with the provided configuration.
   *
   * This method sets up the complete OpenTelemetry pipeline including:
   * - Tracer and logger providers
   * - Exporters for sending data to AWS services
   * - Resource attributes and service identification
   * - Automatic instrumentation e.g. UIKit
   *
   * ## Important Notes
   *
   * - This method can only be called once successfully per application lifecycle
   * - Subsequent calls will return `false` without making changes
   * - The configuration becomes immutable after successful initialization
   *
   * @param config The configuration object containing RUM, application, and telemetry settings
   * @return `true` if initialization was successful, `false` if already initialized or if an error occurred
   */
  @objc @discardableResult
  func initialize(config: AwsOpenTelemetryConfig) -> Bool {
    AwsOpenTelemetryLogger.info("Initializing with region: \(config.aws.region), appMonitorId: \(config.aws.rumAppMonitorId)")

    do {
      try AwsOpenTelemetryRumBuilder.create(config: config).build()
      return true
    } catch AwsOpenTelemetryConfigError.alreadyInitialized {
      AwsOpenTelemetryLogger.debug("SDK is already initialized.")
      return false
    } catch {
      AwsOpenTelemetryLogger.error("Error starting OpenTelemetrySDK: \(error.localizedDescription)")
      return false
    }
  }

  /**
   * Initializes the SDK using the default JSON configuration file.
   *
   * This method looks for aws_config.json in the main bundle and converts it into an
   * AwsOpenTelemetryConfig object. The converted configurations are used to
   * initialize the SDK.
   *
   * @return true if initialization was successful, false otherwise
   */
  @objc @discardableResult
  @_spi(AwsOpenTelemetryAgent) public func initializeWithJsonConfig() -> Bool {
    guard let config = AwsRumConfigReader.loadJsonConfig() else {
      return false
    }

    return initialize(config: config)
  }

  /**
   * Gets a tracer instance configured with AWS OpenTelemetry instrumentation details.
   *
   * This function returns a tracer from the global OpenTelemetry instance, automatically
   * configured with the AWS OpenTelemetry Swift SDK's instrumentation name and version.
   * The tracer can be used to create spans for distributed tracing.
   *
   * @return A Tracer instance configured with AWS instrumentation metadata
   */
  static func getTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(instrumentationName: name, instrumentationVersion: version)
  }

  static func getLogger() -> Logger {
    return OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: "\(name)-v\(version)")
  }
}
