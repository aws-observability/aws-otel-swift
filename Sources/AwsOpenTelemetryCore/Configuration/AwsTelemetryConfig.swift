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
 * Configuration for controlling automatic telemetry instrumentation features.
 *
 * This class allows you to enable or disable specific automatic instrumentation
 * capabilities provided by the AWS OpenTelemetry SDK. Each feature can be
 * controlled independently to match your application's requirements.
 *
 * ## Available Features
 *
 * - **startup**: Application startup instrumentation
 * - **sessionEvents**: Session lifecycle events
 * - **crash**: Crash reporting and analysis
 * - **network**: Network request instrumentation
 * - **hang**: Application hang detection
 * - **view**: View instrumentation (SwiftUI and UIKit)
 *
 * ## Default Behavior
 *
 * By default, all instrumentation features are **enabled** to provide comprehensive
 * observability out of the box. You can selectively disable features if needed.
 *
 */
@objc public class AwsTelemetryConfig: NSObject, Codable {
  public var startup: TelemetryFeature?
  public var sessionEvents: TelemetryFeature?
  public var crash: TelemetryFeature?
  public var network: TelemetryFeature?
  public var hang: TelemetryFeature?
  public var view: TelemetryFeature?

  static let `default` = AwsTelemetryConfig()

  /**
   * Initializes telemetry configuration with all features enabled by default.
   */
  override public init() {
    startup = TelemetryFeature(enabled: true)
    sessionEvents = TelemetryFeature(enabled: true)
    crash = TelemetryFeature(enabled: true)
    network = TelemetryFeature(enabled: true)
    hang = TelemetryFeature(enabled: true)
    view = TelemetryFeature(enabled: true)
    super.init()
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    startup = try container.decodeIfPresent(TelemetryFeature.self, forKey: .startup) ?? TelemetryFeature(enabled: true)
    sessionEvents = try container.decodeIfPresent(TelemetryFeature.self, forKey: .sessionEvents) ?? TelemetryFeature(enabled: true)
    crash = try container.decodeIfPresent(TelemetryFeature.self, forKey: .crash) ?? TelemetryFeature(enabled: true)
    network = try container.decodeIfPresent(TelemetryFeature.self, forKey: .network) ?? TelemetryFeature(enabled: true)
    hang = try container.decodeIfPresent(TelemetryFeature.self, forKey: .hang) ?? TelemetryFeature(enabled: true)
    view = try container.decodeIfPresent(TelemetryFeature.self, forKey: .view) ?? TelemetryFeature(enabled: true)
    super.init()
  }

  /// Creates a new AwsTelemetryConfigBuilder instance
  static func builder() -> AwsTelemetryConfigBuilder {
    return AwsTelemetryConfigBuilder()
  }
}

/// Builder for creating AwsTelemetryConfig instances with a fluent API
public class AwsTelemetryConfigBuilder {
  public private(set) var startup: TelemetryFeature? = TelemetryFeature(enabled: true)
  public private(set) var sessionEvents: TelemetryFeature? = TelemetryFeature(enabled: true)
  public private(set) var crash: TelemetryFeature? = TelemetryFeature(enabled: true)
  public private(set) var network: TelemetryFeature? = TelemetryFeature(enabled: true)
  public private(set) var hang: TelemetryFeature? = TelemetryFeature(enabled: true)
  public private(set) var view: TelemetryFeature? = TelemetryFeature(enabled: true)

  public init() {}

  /// Sets the startup feature
  public func with(startup: TelemetryFeature) -> Self {
    self.startup = startup
    return self
  }

  /// Sets the sessionEvents feature
  public func with(sessionEvents: TelemetryFeature) -> Self {
    self.sessionEvents = sessionEvents
    return self
  }

  /// Sets the crash feature
  public func with(crash: TelemetryFeature) -> Self {
    self.crash = crash
    return self
  }

  /// Sets the network feature
  public func with(network: TelemetryFeature) -> Self {
    self.network = network
    return self
  }

  /// Sets the hang feature
  public func with(hang: TelemetryFeature) -> Self {
    self.hang = hang
    return self
  }

  /// Sets the view feature
  public func with(view: TelemetryFeature) -> Self {
    self.view = view
    return self
  }

  /// Builds the AwsTelemetryConfig with the configured settings
  public func build() -> AwsTelemetryConfig {
    let config = AwsTelemetryConfig()
    config.startup = startup
    config.sessionEvents = sessionEvents
    config.crash = crash
    config.network = network
    config.hang = hang
    config.view = view

    return config
  }
}

/**
 * Represents a single telemetry feature that can be enabled or disabled.
 */
@objc public class TelemetryFeature: NSObject, Codable {
  public var enabled: Bool

  /**
   * Initializes a telemetry feature.
   *
   * @param enabled Whether the feature is enabled (defaults to true)
   */
  public init(enabled: Bool = true) {
    self.enabled = enabled
    super.init()
  }
}
