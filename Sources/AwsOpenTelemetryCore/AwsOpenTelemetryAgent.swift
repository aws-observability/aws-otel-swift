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
import OpenTelemetrySdk
import StdoutExporter
import ResourceExtension
import URLSessionInstrumentation
import OpenTelemetryProtocolExporterHttp

/**
 * This class provides a singleton instance and methods to initialize
 * the OpenTelemetry SDK with AWS-specific configurations.
 */
@objc public class AwsOpenTelemetryAgent: NSObject {
  /// Shared singleton instance
  @objc public static let shared = AwsOpenTelemetryAgent()

  /// Current active configuration
  public internal(set) var configuration: AwsOpenTelemetryConfig?

  /// Flag indicating whether the SDK has been initialized
  @objc public internal(set) var isInitialized: Bool = false

  /// Private initializer to enforce singleton pattern
  override private init() {
    super.init()
  }

  /**
   * Initializes the SDK with configurations defined as an AwsOpenTelemetryConfig object.
   *
   * @param config The configuration to use for initialization
   * @return true if initialization was successful, false otherwise
   */
  @objc @discardableResult
  func initialize(config: AwsOpenTelemetryConfig) -> Bool {
    print("[AwsOpenTelemetry] Initializing with region: \(config.rum.region), appMonitorId: \(config.rum.appMonitorId)")

    do {
      try AwsOpenTelemetryRumBuilder.create(config: config).build()
      return true
    } catch AwsOpenTelemetryConfigError.alreadyInitialized {
      print("[AwsOpenTelemetry] SDK is already initialized.")
      return false
    } catch {
      print("[AwsOpenTelemetry] Error starting OpenTelemetrySDK: \(error.localizedDescription)")
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
}
