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
 *   .addInstrumentation(AwsURLSessionInstrumentation(config: config.rum))
 *   .build()
 * ```
 */
public class AwsURLSessionInstrumentation: AwsOpenTelemetryInstrumentationProtocol {
  /// Set of URLs that should be excluded from instrumentation
  private let urlsToExclude: Set<String>
  private let config: RumConfig
  private var isApplied = false

  /**
   * Initializes the AWS URLSession instrumentation configuration.
   * The instrumentation will be applied when apply() is called.
   */
  public init(config: RumConfig) {
    self.config = config
    // Get OTLP endpoints from config but don't create instrumentation yet
    urlsToExclude = buildOtlpEndpoints(config: config)
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
        let shouldInstrument = !self.shouldExcludeURL(request)
        return shouldInstrument
      }
    )
    _ = URLSessionInstrumentation(configuration: urlSessionConfig)

    isApplied = true
  }

  // MARK: - Private Helper Methods

  /**
   * Determines whether a URLRequest should be excluded from instrumentation
   */
  private func shouldExcludeURL(_ request: URLRequest) -> Bool {
    guard let url = request.url else {
      return false
    }

    let requestURL = url.absoluteString

    for url in urlsToExclude {
      if requestURL.hasPrefix(url) {
        AwsOpenTelemetryLogger.debug("Excluding requestUrl=\(url)")
        return true
      }
    }
    AwsOpenTelemetryLogger.debug("Recording requestUrl=\(url)")
    return false
  }
}
