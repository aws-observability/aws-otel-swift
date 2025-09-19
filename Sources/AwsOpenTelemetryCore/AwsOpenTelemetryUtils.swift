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

// MARK: - Endpoint Construction

/**
 * Builds the traces endpoint URL.
 *
 * @param region The AWS region
 * @param exportOverride Optional export overrides
 * @return The traces endpoint URL
 */
public func buildTracesEndpoint(region: String, exportOverride: ExportOverride?) -> String {
  return exportOverride?.traces ?? buildRumEndpoint(region: region)
}

/**
 * Builds the logs endpoint URL.
 *
 * @param region The AWS region
 * @param exportOverride Optional export overrides
 * @return The logs endpoint URL
 */
public func buildLogsEndpoint(region: String, exportOverride: ExportOverride?) -> String {
  return exportOverride?.logs ?? buildRumEndpoint(region: region)
}

/**
 * Gets the set of OTLP endpoint URLs
 *
 * @param region The AWS region
 * @param exportOverride Optional export overrides
 * @return Set of OTLP endpoint URLs
 */
public func buildOtlpEndpoints(region: String, exportOverride: ExportOverride?) -> Set<String> {
  let tracesEndpoint = buildTracesEndpoint(region: region, exportOverride: exportOverride)
  let logsEndpoint = buildLogsEndpoint(region: region, exportOverride: exportOverride)

  // Use Set to automatically handle duplicates when traces and logs use the same endpoint
  let endpoints = Set([tracesEndpoint, logsEndpoint])

  print("excluded endpoints: \(endpoints)")

  return endpoints
}
