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
/// These are pure (no simulator, no network, no files), so they run wherever the package's
/// ordinary unit tests run: `swift test --skip ContractTests` (hence `make check-coverage`) and
/// the `make test-*` platform targets, which skip only the `ContractTests` target by name.
///
/// They are deliberately *not* reached by the contract test step's
/// `swift test --filter ContractTests` — that regex does not match `ContractTestConfigTests` —
/// because they assert resolution rules, not exported payloads.
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
    let unusable = [
      "not-a-url",
      "localhost:3000",
      "ftp://localhost:3000",
      "http://",
      "http:///v1/rum",
      // A query or fragment cannot be reconciled with appending a per-signal path, so it is
      // rejected rather than silently mangled into `http://host?x=1/v1/logs`.
      "http://localhost:3000?x=1",
      "http://localhost:3000#frag",
      "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum?x=1",
      // Embedded credentials would be dropped when the origin is reassembled, silently
      // retargeting the exporter. Rejected instead.
      "http://user:pass@localhost:3000",
      "http://user@localhost:3000/v1/rum"
    ]

    for value in unusable {
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

  /// The origin is rebuilt from the parsed URL rather than sliced out of the raw string, so
  /// cosmetic differences in the input cannot produce a malformed export URL. (The
  /// trailing-slash form is covered by `testOriginOnlyEndpointGetsPerSignalOtlpPaths`.)
  func testOriginIsNormalizedBeforeThePerSignalPathIsAppended() {
    let config = ContractTestConfig.resolve(environment: [
      ContractTestConfig.endpointKey: "HTTP://localhost:3000"
    ])

    XCTAssertEqual(
      config.endpoints,
      .override(logs: "http://localhost:3000/v1/logs", traces: "http://localhost:3000/v1/traces")
    )
  }

  /// A host with no port must not gain a stray colon when the origin is reassembled.
  func testOriginWithoutAPortKeepsItsShape() {
    let config = ContractTestConfig.resolve(environment: [
      ContractTestConfig.endpointKey: "https://dataplane.rum.us-east-1.amazonaws.com"
    ])

    XCTAssertEqual(
      config.endpoints,
      .override(
        logs: "https://dataplane.rum.us-east-1.amazonaws.com/v1/logs",
        traces: "https://dataplane.rum.us-east-1.amazonaws.com/v1/traces"
      )
    )
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

  // MARK: - Run id (the put-to-get correlation key)

  /// Given no run id, when the config is resolved, then there is no correlation key and the
  /// resource attributes are exactly the two the demo app has always shipped. The hermetic
  /// default path must not gain an attribute.
  func testUnsetRunIdLeavesResourceAttributesUnchanged() {
    let config = ContractTestConfig.resolve(environment: [:])

    XCTAssertNil(config.runId)
    XCTAssertEqual(
      config.otelResourceAttributes,
      ["service.name": "SimpleAwsDemo", "service.version": "1.0.0"]
    )
  }

  /// An unset CI value arrives as an empty string once it has been threaded through `make`.
  func testEmptyRunIdIsTreatedAsUnset() {
    for value in ["", " ", "\n", "  \n\t "] {
      let config = ContractTestConfig.resolve(environment: [ContractTestConfig.runIdKey: value])

      XCTAssertNil(config.runId, "expected \(value.debugDescription) to be treated as unset")
      XCTAssertNil(
        config.otelResourceAttributes[ContractTestConfig.runIdAttributeKey],
        "expected \(value.debugDescription) not to become a resource attribute"
      )
    }
  }

  func testRunIdIsTrimmed() {
    let config = ContractTestConfig.resolve(environment: [
      ContractTestConfig.runIdKey: " 32515418069-2\n"
    ])

    XCTAssertEqual(config.runId, "32515418069-2")
  }

  /// Given a run id, when the config is resolved, then it is carried as a resource attribute so
  /// it reaches the exported payload — that is what the put-to-get workflow greps CloudWatch
  /// Logs for. The pre-existing attributes must survive alongside it.
  func testRunIdBecomesAResourceAttribute() {
    let config = ContractTestConfig.resolve(environment: [
      ContractTestConfig.runIdKey: "32515418069-2"
    ])

    XCTAssertEqual(
      config.otelResourceAttributes,
      [
        "service.name": "SimpleAwsDemo",
        "service.version": "1.0.0",
        ContractTestConfig.runIdAttributeKey: "32515418069-2"
      ]
    )
  }

  /// The attribute key is a cross-language contract: `scripts/verify-put-to-get.sh` searches the
  /// log group for the *value*, but a human debugging a failed run looks for this key. Pin it so
  /// renaming it is a deliberate, reviewed change.
  func testRunIdAttributeKeyIsStable() {
    XCTAssertEqual(ContractTestConfig.runIdAttributeKey, "aws.otel.contract.run.id")
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
    XCTAssertEqual(
      config.otelResourceAttributes,
      ["service.name": "SimpleAwsDemo", "service.version": "1.0.0"]
    )
  }

  /// `UITests/EmptyUITests.swift` forwards harness variables into the simulator by prefix
  /// rather than by name, so every key this type reads must carry that prefix.
  func testEveryEnvironmentKeySharesTheForwardingPrefix() {
    for key in [
      ContractTestConfig.endpointKey,
      ContractTestConfig.regionKey,
      ContractTestConfig.appMonitorIdKey,
      ContractTestConfig.runIdKey
    ] {
      XCTAssertTrue(key.hasPrefix(ContractTestConfig.environmentKeyPrefix), "\(key) is not forwardable")
    }
  }
}
