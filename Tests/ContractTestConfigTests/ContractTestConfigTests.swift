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

import XCTest
@testable import ContractTestConfig

/// Unit tests for the contract test harness' environment resolution.
///
/// These are pure (no simulator, no network, no files) so they run anywhere
/// `swift test` runs, including as part of `swift test --filter ContractTests`.
class ContractTestConfigTests: XCTestCase {
  // MARK: - No endpoint supplied

  /// Given no endpoint in the environment, when the config is resolved, then no export
  /// override is described at all, so the SDK falls through to the real regional endpoint.
  func testUnsetEndpointResolvesToNoOverride() {
    let config = ContractTestConfig.resolve(environment: [:])

    XCTAssertEqual(config.endpoints, .unset)
  }

  /// Given an endpoint that is set but empty (how an unset CI secret arrives once it has
  /// been threaded through `make`), when the config is resolved, then it is treated as
  /// unset rather than becoming a literal empty override.
  func testEmptyEndpointResolvesToNoOverride() {
    for value in ["", " ", "\n", "  \n\t "] {
      let config = ContractTestConfig.resolve(environment: [ContractTestConfig.endpointKey: value])

      XCTAssertEqual(config.endpoints, .unset, "expected \(value.debugDescription) to be treated as unset")
    }
  }

  // MARK: - Endpoint supplied

  /// Given an origin-only endpoint, when the config is resolved, then the standard OTLP
  /// per-signal paths are appended — this is what keeps the hermetic localhost run working.
  func testOriginOnlyEndpointGetsPerSignalOtlpPaths() {
    for value in ["http://localhost:3000", "http://localhost:3000/", "  http://localhost:3000  "] {
      let config = ContractTestConfig.resolve(environment: [ContractTestConfig.endpointKey: value])

      XCTAssertEqual(
        config.endpoints,
        .override(logs: "http://localhost:3000/v1/logs", traces: "http://localhost:3000/v1/traces"),
        "unexpected resolution for \(value.debugDescription)"
      )
    }
  }

  /// Given an endpoint that already carries a path, when the config is resolved, then it is
  /// used verbatim for both signals. CloudWatch RUM accepts both signals on `/v1/rum`.
  func testEndpointWithPathIsUsedVerbatimForBothSignals() {
    let endpoint = "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum"

    let config = ContractTestConfig.resolve(environment: [ContractTestConfig.endpointKey: endpoint])

    XCTAssertEqual(config.endpoints, .override(logs: endpoint, traces: endpoint))
  }

  /// Given an endpoint that cannot be used, when the config is resolved, then the failure is
  /// reported explicitly instead of silently falling back to the real regional endpoint.
  func testUnusableEndpointIsReportedAsInvalid() {
    for value in ["not-a-url", "localhost:3000", "ftp://localhost:3000", "http://", "http:///v1/rum"] {
      let config = ContractTestConfig.resolve(environment: [ContractTestConfig.endpointKey: value])

      guard case let .invalid(reason) = config.endpoints else {
        XCTFail("expected \(value.debugDescription) to be reported invalid, got \(config.endpoints)")
        continue
      }
      XCTAssertTrue(
        reason.contains(ContractTestConfig.endpointKey),
        "reason should name the offending variable so a failing run is diagnosable: \(reason)"
      )
    }
  }

  // MARK: - Region and app monitor id

  func testRegionAndAppMonitorIdComeFromTheEnvironment() {
    let config = ContractTestConfig.resolve(environment: [
      ContractTestConfig.regionKey: "us-west-2",
      ContractTestConfig.appMonitorIdKey: "2a572e14-0000-0000-0000-000000000000"
    ])

    XCTAssertEqual(config.region, "us-west-2")
    XCTAssertEqual(config.appMonitorId, "2a572e14-0000-0000-0000-000000000000")
  }

  /// CI secrets routinely arrive with a trailing newline; that must not reach the SDK.
  func testRegionAndAppMonitorIdAreTrimmed() {
    let config = ContractTestConfig.resolve(environment: [
      ContractTestConfig.regionKey: " us-west-2\n",
      ContractTestConfig.appMonitorIdKey: "\tan-app-monitor-id \n"
    ])

    XCTAssertEqual(config.region, "us-west-2")
    XCTAssertEqual(config.appMonitorId, "an-app-monitor-id")
  }

  func testEmptyRegionAndAppMonitorIdFallBackToHermeticDefaults() {
    let config = ContractTestConfig.resolve(environment: [
      ContractTestConfig.regionKey: "",
      ContractTestConfig.appMonitorIdKey: "  \n"
    ])

    XCTAssertEqual(config.region, ContractTestConfig.defaultRegion)
    XCTAssertEqual(config.appMonitorId, ContractTestConfig.defaultAppMonitorId)
  }

  // MARK: - Regression guards

  /// The hermetic contract test assertions pin these exact values
  /// (`Tests/ContractTests/ResourceAttributesTests.swift`), and
  /// `scripts/run-contract-tests.sh` supplies the localhost endpoint. Resolving that
  /// environment must reproduce today's configuration exactly.
  func testHermeticEnvironmentReproducesTodaysConfiguration() {
    let config = ContractTestConfig.resolve(environment: [
      ContractTestConfig.endpointKey: "http://localhost:3000"
    ])

    XCTAssertEqual(config.region, "us-east-1")
    XCTAssertEqual(config.appMonitorId, "test-app-monitor-id")
    XCTAssertEqual(
      config.endpoints,
      .override(logs: "http://localhost:3000/v1/logs", traces: "http://localhost:3000/v1/traces")
    )
  }

  /// `UITests/EmptyUITests.swift` forwards harness variables into the simulator by prefix
  /// rather than by name, so every key this type reads must carry that prefix.
  func testEveryEnvironmentKeySharesTheForwardingPrefix() {
    for key in [ContractTestConfig.endpointKey, ContractTestConfig.regionKey, ContractTestConfig.appMonitorIdKey] {
      XCTAssertTrue(key.hasPrefix(ContractTestConfig.environmentKeyPrefix), "\(key) is not forwardable")
    }
  }
}
