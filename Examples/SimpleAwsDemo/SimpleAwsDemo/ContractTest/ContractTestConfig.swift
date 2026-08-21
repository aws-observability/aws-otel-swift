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

/// How the export endpoint was resolved from the environment.
public enum ContractTestEndpointResolution: Equatable {
  /// No endpoint was supplied. No `AwsExportOverride` must be constructed, so the SDK
  /// targets the real regional endpoint (`https://dataplane.rum.<region>.amazonaws.com/v1/rum`).
  case unset

  /// An endpoint was supplied and is usable.
  case override(logs: String, traces: String)

  /// An endpoint was supplied but cannot be used. Callers must fail loudly rather than
  /// fall back to `unset`: silently retargeting a test run at the real data plane is worse
  /// than not exporting at all.
  case invalid(reason: String)
}

/// Contract test harness configuration, resolved from the process environment.
///
/// The harness (`scripts/run-contract-tests.sh` → `Examples/SimpleAwsDemo/Makefile` →
/// `xcodebuild` → `UITests/EmptyUITests.swift`) hands these values to the demo app through
/// the simulator **launch environment**. They are deliberately not launch arguments: the app
/// prints `ProcessInfo.processInfo.arguments` at startup, and the app monitor id is a CI
/// secret.
///
/// With nothing set the resolved values are the real regional endpoint plus the placeholder
/// region/app monitor id the demo app has always shipped. The hermetic localhost endpoint comes
/// from the harness, which defaults it at both entry points: `scripts/run-contract-tests.sh` and
/// `Examples/SimpleAwsDemo/Makefile` (so the make targets stay hermetic when invoked directly).
public struct ContractTestConfig: Equatable {
  /// Shared prefix for every variable the harness forwards. `UITests/EmptyUITests.swift`
  /// forwards by prefix, so a new variable needs no change there.
  public static let environmentKeyPrefix = "AWS_OTEL_CONTRACT_"

  /// Export endpoint. Either an origin (`http://localhost:3000`), in which case the standard
  /// OTLP per-signal paths are appended, or a full URL (`.../v1/rum`), used verbatim for both
  /// signals — CloudWatch RUM accepts logs and traces on the same path.
  public static let endpointKey = environmentKeyPrefix + "EXPORT_ENDPOINT"

  /// AWS region passed to `AwsConfig`.
  public static let regionKey = environmentKeyPrefix + "REGION"

  /// RUM app monitor **id** (a UUID, not the monitor name) passed to `AwsConfig`. A secret in CI.
  public static let appMonitorIdKey = environmentKeyPrefix + "APP_MONITOR_ID"

  /// Region used when none is supplied. Pinned by `Tests/ContractTests/ResourceAttributesTests.swift`.
  public static let defaultRegion = "us-east-1"

  /// App monitor id used when none is supplied. Pinned by `Tests/ContractTests/ResourceAttributesTests.swift`.
  public static let defaultAppMonitorId = "test-app-monitor-id"

  private static let logsPath = "/v1/logs"
  private static let tracesPath = "/v1/traces"
  private static let allowedSchemes = ["http", "https"]

  public let region: String
  public let appMonitorId: String
  public let endpoints: ContractTestEndpointResolution

  /// Resolves the harness configuration from an environment dictionary.
  ///
  /// Every value is trimmed — CI secrets routinely arrive with a trailing newline — and an
  /// empty value is treated exactly like an absent one.
  public static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment) -> ContractTestConfig {
    ContractTestConfig(
      region: value(for: regionKey, in: environment) ?? defaultRegion,
      appMonitorId: value(for: appMonitorIdKey, in: environment) ?? defaultAppMonitorId,
      endpoints: resolveEndpoints(value(for: endpointKey, in: environment))
    )
  }

  private static func value(for key: String, in environment: [String: String]) -> String? {
    guard let raw = environment[key] else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func resolveEndpoints(_ endpoint: String?) -> ContractTestEndpointResolution {
    guard let endpoint else { return .unset }

    guard let components = URLComponents(string: endpoint),
          let scheme = components.scheme?.lowercased(),
          allowedSchemes.contains(scheme),
          let host = components.host,
          !host.isEmpty,
          components.query == nil,
          components.fragment == nil,
          components.user == nil,
          components.password == nil else {
      return .invalid(
        reason: "\(endpointKey) must be an http(s) URL with a host and no query, fragment or "
          + "embedded credentials, e.g. http://localhost:3000 or "
          + "https://dataplane.rum.<region>.amazonaws.com/v1/rum"
      )
    }

    let path = components.path
    guard path.isEmpty || path == "/" else {
      // Already a per-signal (or single-path) URL: use it as given.
      return .override(logs: endpoint, traces: endpoint)
    }

    // Rebuild the origin from the parsed components rather than slicing the input, so a
    // trailing slash, an uppercase scheme or any other cosmetic difference cannot produce a
    // malformed URL once the per-signal path is appended.
    var originComponents = URLComponents()
    originComponents.scheme = scheme
    originComponents.host = host
    originComponents.port = components.port
    guard let origin = originComponents.string else {
      return .invalid(reason: "\(endpointKey) could not be normalized into an origin URL")
    }
    return .override(logs: origin + logsPath, traces: origin + tracesPath)
  }
}
