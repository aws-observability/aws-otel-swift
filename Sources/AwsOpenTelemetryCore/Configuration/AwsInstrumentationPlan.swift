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
      return Self.default
    }

    let networkEnabled = telemetry.network?.enabled == true
    let crashEnabled = telemetry.crash?.enabled == true
    let hangEnabled = telemetry.hang?.enabled == true

    let urlSessionConfig = networkEnabled ? AwsURLSessionConfig(region: config.aws.region, exportOverride: config.exportOverride) : nil
    let metricKitConfig = (crashEnabled || hangEnabled) ? AwsMetricKitConfig(crashes: crashEnabled, hangs: hangEnabled) : nil

    return AwsInstrumentationPlan(
      sessionEvents: telemetry.sessionEvents?.enabled == true,
      view: telemetry.view?.enabled == true,
      crash: crashEnabled,
      hang: hangEnabled,
      network: networkEnabled,
      urlSessionConfig: urlSessionConfig,
      metricKitConfig: metricKitConfig
    )
  }
}
