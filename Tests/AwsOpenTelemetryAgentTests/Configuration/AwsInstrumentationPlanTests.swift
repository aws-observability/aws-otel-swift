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
@testable import AwsOpenTelemetryCore

final class AwsInstrumentationPlanTests: XCTestCase {
  func testDefaultInitialization() {
    let plan = AwsInstrumentationPlan.default

    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.hang)
    XCTAssertFalse(plan.network)
    XCTAssertNil(plan.urlSessionConfig)
    XCTAssertNil(plan.metricKitConfig)
  }

  func testFromConfigWithNilTelemetry() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-east-1", rumAppMonitorId: "test-id"),
      telemetry: nil
    )

    let plan = AwsInstrumentationPlan.from(config: config)

    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.hang)
    XCTAssertFalse(plan.network)
  }

  func testFromConfigWithAllEnabled() {
    let telemetry = TelemetryConfig.builder()
      .with(sessionEvents: TelemetryFeature(enabled: true))
      .with(view: TelemetryFeature(enabled: true))
      .with(crash: TelemetryFeature(enabled: true))
      .with(hang: TelemetryFeature(enabled: true))
      .with(network: TelemetryFeature(enabled: true))
      .build()

    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      telemetry: telemetry
    )

    let plan = AwsInstrumentationPlan.from(config: config)

    XCTAssertTrue(plan.sessionEvents)
    XCTAssertTrue(plan.view)
    XCTAssertTrue(plan.crash)
    XCTAssertTrue(plan.hang)
    XCTAssertTrue(plan.network)
    XCTAssertEqual(plan.urlSessionConfig?.region, "us-west-2")
    XCTAssertEqual(plan.metricKitConfig?.crashes, true)
    XCTAssertEqual(plan.metricKitConfig?.hangs, true)
  }

  func testCrashOnlyEnabled() {
    let telemetry = TelemetryConfig.builder()
      .with(crash: TelemetryFeature(enabled: true))
      .with(sessionEvents: TelemetryFeature(enabled: false))
      .with(view: TelemetryFeature(enabled: false))
      .with(network: TelemetryFeature(enabled: false))
      .with(hang: TelemetryFeature(enabled: false))
      .build()

    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-east-1", rumAppMonitorId: "test-id"),
      telemetry: telemetry
    )

    let plan = AwsInstrumentationPlan.from(config: config)

    XCTAssertTrue(plan.crash)
    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.hang)
    XCTAssertFalse(plan.network)
    XCTAssertNil(plan.urlSessionConfig)
    XCTAssertEqual(plan.metricKitConfig?.crashes, true)
    XCTAssertEqual(plan.metricKitConfig?.hangs, false)
  }

  func testNetworkOnlyEnabled() {
    let telemetry = TelemetryConfig.builder()
      .with(network: TelemetryFeature(enabled: true))
      .with(sessionEvents: TelemetryFeature(enabled: false))
      .with(view: TelemetryFeature(enabled: false))
      .with(crash: TelemetryFeature(enabled: false))
      .with(hang: TelemetryFeature(enabled: false))
      .build()

    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "eu-west-1", rumAppMonitorId: "test-id"),
      telemetry: telemetry
    )

    let plan = AwsInstrumentationPlan.from(config: config)

    XCTAssertTrue(plan.network)
    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.hang)
    XCTAssertEqual(plan.urlSessionConfig?.region, "eu-west-1")
    XCTAssertNil(plan.metricKitConfig)
  }

  func testSessionEventsOnlyEnabled() {
    let telemetry = TelemetryConfig.builder()
      .with(sessionEvents: TelemetryFeature(enabled: true))
      .with(view: TelemetryFeature(enabled: false))
      .with(crash: TelemetryFeature(enabled: false))
      .with(hang: TelemetryFeature(enabled: false))
      .with(network: TelemetryFeature(enabled: false))
      .build()

    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "ap-south-1", rumAppMonitorId: "test-id"),
      telemetry: telemetry
    )

    let plan = AwsInstrumentationPlan.from(config: config)

    XCTAssertTrue(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.hang)
    XCTAssertFalse(plan.network)
    XCTAssertNil(plan.urlSessionConfig)
    XCTAssertNil(plan.metricKitConfig)
  }

  func testViewOnlyEnabled() {
    let telemetry = TelemetryConfig.builder()
      .with(view: TelemetryFeature(enabled: true))
      .with(sessionEvents: TelemetryFeature(enabled: false))
      .with(crash: TelemetryFeature(enabled: false))
      .with(hang: TelemetryFeature(enabled: false))
      .with(network: TelemetryFeature(enabled: false))
      .build()

    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "ca-central-1", rumAppMonitorId: "test-id"),
      telemetry: telemetry
    )

    let plan = AwsInstrumentationPlan.from(config: config)

    XCTAssertTrue(plan.view)
    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.hang)
    XCTAssertFalse(plan.network)
    XCTAssertNil(plan.urlSessionConfig)
    XCTAssertNil(plan.metricKitConfig)
  }

  func testHangOnlyEnabled() {
    let telemetry = TelemetryConfig.builder()
      .with(hang: TelemetryFeature(enabled: true))
      .with(sessionEvents: TelemetryFeature(enabled: false))
      .with(view: TelemetryFeature(enabled: false))
      .with(crash: TelemetryFeature(enabled: false))
      .with(network: TelemetryFeature(enabled: false))
      .build()

    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "eu-central-1", rumAppMonitorId: "test-id"),
      telemetry: telemetry
    )

    let plan = AwsInstrumentationPlan.from(config: config)

    XCTAssertTrue(plan.hang)
    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.network)
    XCTAssertNil(plan.urlSessionConfig)
    XCTAssertEqual(plan.metricKitConfig?.crashes, false)
    XCTAssertEqual(plan.metricKitConfig?.hangs, true)
  }

  func testNetworkWithExportOverride() {
    let telemetry = TelemetryConfig.builder()
      .with(network: TelemetryFeature(enabled: true))
      .with(sessionEvents: TelemetryFeature(enabled: false))
      .with(view: TelemetryFeature(enabled: false))
      .with(crash: TelemetryFeature(enabled: false))
      .with(hang: TelemetryFeature(enabled: false))
      .build()
    let exportOverride = ExportOverride(
      logs: "http://localhost:4318/v1/logs",
      traces: "http://localhost:4318/v1/traces"
    )
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id"),
      exportOverride: exportOverride,
      telemetry: telemetry
    )

    let plan = AwsInstrumentationPlan.from(config: config)

    XCTAssertTrue(plan.network)
    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.hang)
    XCTAssertNil(plan.metricKitConfig)
    XCTAssertEqual(plan.urlSessionConfig?.region, "us-west-2")
    XCTAssertEqual(plan.urlSessionConfig?.exportOverride?.traces, "http://localhost:4318/v1/traces")
    XCTAssertEqual(plan.urlSessionConfig?.exportOverride?.logs, "http://localhost:4318/v1/logs")
  }
}
