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
 * AWS OpenTelemetry Utilities
 *
 * This file contains utility functions for AWS RUM (Real User Monitoring) configuration
 * and OpenTelemetry Protocol (OTLP) management. These utilities provide common functionality
 * used throughout the AWS OpenTelemetry SDK for configuration management, URL construction,
 * telemetry data routing, and instrumentation support.
 *
 */

// MARK: - RUM Endpoint Construction

/**
 * Builds the base RUM endpoint URL for a given region.
 *
 * @param region The AWS region
 * @return The base RUM endpoint URL
 */
public func buildRumEndpoint(region: String) -> String {
  return "https://dataplane.rum.\(region).amazonaws.com/v1/rum"
}

/**
 * Builds the traces endpoint URL.
 *
 * @param config The RUM configuration
 * @return The traces endpoint URL
 */
public func buildTracesEndpoint(config: RumConfig) -> String {
  return config.overrideEndpoint?.traces ?? buildRumEndpoint(region: config.region)
}

/**
 * Builds the logs endpoint URL.
 *
 * @param config The RUM configuration
 * @return The logs endpoint URL
 */
public func buildLogsEndpoint(config: RumConfig) -> String {
  return config.overrideEndpoint?.logs ?? buildRumEndpoint(region: config.region)
}

/**
 * Gets the set of OTLP endpoint URLs
 */
public func buildOtlpEndpoints(config: RumConfig) -> Set<String> {
  let tracesEndpoint = buildTracesEndpoint(config: config)
  let logsEndpoint = buildLogsEndpoint(config: config)

  // Use Set to automatically handle duplicates when traces and logs use the same endpoint
  let endpoints = Set([tracesEndpoint, logsEndpoint])

  return endpoints
}
