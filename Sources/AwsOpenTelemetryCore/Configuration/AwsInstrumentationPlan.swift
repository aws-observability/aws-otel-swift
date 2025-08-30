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

/// Encapsulates the decision logic to build instrumentations and subconfigurations during AwsOpenTelemetryRumBuilder
struct AwsInstrumentationPlan {
  let sessionEvents: Bool
  let view: Bool
  let crash: Bool
  let hang: Bool
  let network: Bool
  let urlSessionConfig: AwsURLSessionConfig?
  let metricKitConfig: AwsMetricKitConfig?

  static let `default` = AwsInstrumentationPlan()

  init(sessionEvents: Bool = false,
       view: Bool = false,
       crash: Bool = false,
       hang: Bool = false,
       network: Bool = false,
       urlSessionConfig: AwsURLSessionConfig? = nil,
       metricKitConfig: AwsMetricKitConfig? = nil) {
    self.sessionEvents = sessionEvents
    self.view = view
    self.crash = crash
    self.hang = hang
    self.network = network
    self.urlSessionConfig = urlSessionConfig
    self.metricKitConfig = metricKitConfig
  }

  /// Creates an AwsInstrumentationPlan from AwsOpenTelemetryConfig
  static func from(config: AwsOpenTelemetryConfig) -> AwsInstrumentationPlan {
    guard let telemetry: TelemetryConfig = config.telemetry else {
      AwsOpenTelemetryLogger.debug("No telemetry config provided, using default plan")
      return Self.default
    }

    let networkEnabled = telemetry.network?.enabled == true
    let crashEnabled = telemetry.crash?.enabled == true
    let hangEnabled = telemetry.hang?.enabled == true
    let sessionEventsEnabled = telemetry.sessionEvents?.enabled == true
    let viewEnabled = telemetry.view?.enabled == true

    AwsOpenTelemetryLogger.debug("Creating instrumentation plan: sessionEvents=\(sessionEventsEnabled), view=\(viewEnabled), crash=\(crashEnabled), hang=\(hangEnabled), network=\(networkEnabled)")

    let urlSessionConfig = networkEnabled ? AwsURLSessionConfig(region: config.aws.region, exportOverride: config.exportOverride) : nil
    let metricKitConfig = (crashEnabled || hangEnabled) ? AwsMetricKitConfig(crashes: crashEnabled, hangs: hangEnabled) : nil

    if urlSessionConfig != nil {
      var overrideInfo = ""
      if let exportOverride = config.exportOverride {
        let tracesInfo = exportOverride.traces != nil ? "traces=\(exportOverride.traces!)" : ""
        let logsInfo = exportOverride.logs != nil ? "logs=\(exportOverride.logs!)" : ""
        let overrides = [tracesInfo, logsInfo].filter { !$0.isEmpty }.joined(separator: ", ")
        overrideInfo = overrides.isEmpty ? "" : ", overrides: \(overrides)"
      }
      AwsOpenTelemetryLogger.debug("URLSession config created for region: \(config.aws.region)\(overrideInfo)")
    }
    if metricKitConfig != nil {
      AwsOpenTelemetryLogger.debug("MetricKit config created with crashes=\(crashEnabled), hangs=\(hangEnabled)")
    }

    return AwsInstrumentationPlan(
      sessionEvents: sessionEventsEnabled,
      view: viewEnabled,
      crash: crashEnabled,
      hang: hangEnabled,
      network: networkEnabled,
      urlSessionConfig: urlSessionConfig,
      metricKitConfig: metricKitConfig
    )
  }
}
