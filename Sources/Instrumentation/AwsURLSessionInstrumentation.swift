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
import URLSessionInstrumentation
import AwsOpenTelemetryCore

/**
 * AWS-specific URLSession instrumentation that provides automatic network request telemetry
 * for iOS applications using the AWS Distro for OpenTelemetry.
 *
 * This class wraps the OpenTelemetry URLSession instrumentation with AWS-specific configuration,
 * automatically excluding OTLP telemetry endpoints to prevent recursive instrumentation.
 *
 * Usage: Add this instrumentation via the RUM builder:
 * ```
 * try AwsOpenTelemetryRumBuilder.create(config: config)
 *   .addInstrumentation(AwsURLSessionInstrumentation())
 *   .build()
 * ```
 */
public class AwsURLSessionInstrumentation: AwsOpenTelemetryInstrumentationProtocol {
  /// Set of OTLP endpoint URLs that should be excluded from instrumentation
  /// to prevent recursive telemetry collection
  private let otlpEndpoints: Set<String>
  private let config: RumConfig
  private var isApplied = false

  /**
   * Initializes the AWS URLSession instrumentation configuration.
   * The instrumentation will be applied when apply() is called.
   */
  public init(config: RumConfig) {
    self.config = config
    // Get OTLP endpoints from config but don't create instrumentation yet
    otlpEndpoints = Self.buildOtlpEndpoints(config: config)
  }

  /**
   * Applies the URLSession instrumentation.
   * This should be called after OpenTelemetry is fully initialized.
   */
  public func apply() {
    guard !isApplied else {
      return
    }

    let urlSessionConfig = URLSessionInstrumentationConfiguration(
      shouldInstrument: { request in
        let shouldInstrument = !self.isOtlpEndpoint(request)
        return shouldInstrument
      }
    )

    // Create and discard reference (like original working pattern)
    _ = URLSessionInstrumentation(configuration: urlSessionConfig)

    isApplied = true
  }

  // MARK: - Private Helper Methods

  /**
   * Determines whether a URLRequest should be excluded from instrumentation
   * based on the configured OTLP endpoints.
   */
  private func isOtlpEndpoint(_ request: URLRequest) -> Bool {
    guard let url = request.url else {
      return false
    }

    let requestURL = url.absoluteString

    for endpoint in otlpEndpoints {
      if requestURL.hasPrefix(endpoint) {
        return true
      }
    }
    return false
  }

  /**
   * Gets the set of OTLP endpoint URLs that should be excluded from instrumentation
   * to avoid creating telemetry about telemetry.
   *
   * @return Set of OTLP endpoint URLs
   */
  private static func buildOtlpEndpoints(config: RumConfig) -> Set<String> {
    let tracesEndpoint = config.overrideEndpoint?.traces ?? buildRumEndpoint(region: config.region)
    let logsEndpoint = config.overrideEndpoint?.logs ?? buildRumEndpoint(region: config.region)
    let endpoints = Set([tracesEndpoint, logsEndpoint])

    return endpoints
  }

  /**
   * Builds the base RUM endpoint URL for a given region.
   *
   * @param region The AWS region
   * @return The base RUM endpoint URL
   */
  private static func buildRumEndpoint(region: String) -> String {
    return "https://dataplane.rum.\(region).amazonaws.com/v1/rum"
  }
}
