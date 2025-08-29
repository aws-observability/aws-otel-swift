import XCTest
@testable import AwsOpenTelemetryCore

final class AwsOpenTelemetryRumBuilderInstrumentationTests: XCTestCase {
  func testInstrumentationPlanWithNoTelemetryConfig() {
    let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id")
    let config = AwsOpenTelemetryConfig(aws: awsConfig, telemetry: nil)

    let builder = try! AwsOpenTelemetryRumBuilder.create(config: config)
    let plan = builder.instrumentationPlan

    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.network)
  }

  func testInstrumentationPlanWithAllEnabled() {
    let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id")
    let telemetryConfig = TelemetryConfig.builder()
      .with(sessionEvents: TelemetryFeature(enabled: true))
      .with(view: TelemetryFeature(enabled: true))
      .with(crash: TelemetryFeature(enabled: true))
      .with(network: TelemetryFeature(enabled: true))
      .build()
    let config = AwsOpenTelemetryConfig(aws: awsConfig, telemetry: telemetryConfig)

    let builder = try! AwsOpenTelemetryRumBuilder.create(config: config)
    let plan = builder.instrumentationPlan

    XCTAssertTrue(plan.sessionEvents)
    XCTAssertTrue(plan.view)
    XCTAssertTrue(plan.crash)
    XCTAssertTrue(plan.network)
  }

  func testInstrumentationPlanWithAllDisabled() {
    let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id")
    let telemetryConfig = TelemetryConfig.builder()
      .with(sessionEvents: TelemetryFeature(enabled: false))
      .with(view: TelemetryFeature(enabled: false))
      .with(crash: TelemetryFeature(enabled: false))
      .with(network: TelemetryFeature(enabled: false))
      .build()
    let config = AwsOpenTelemetryConfig(aws: awsConfig, telemetry: telemetryConfig)

    let builder = try! AwsOpenTelemetryRumBuilder.create(config: config)
    let plan = builder.instrumentationPlan

    XCTAssertFalse(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertFalse(plan.crash)
    XCTAssertFalse(plan.network)
  }

  func testInstrumentationPlanWithMixedConfiguration() {
    let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id")
    let telemetryConfig = TelemetryConfig.builder()
      .with(sessionEvents: TelemetryFeature(enabled: true))
      .with(view: TelemetryFeature(enabled: false))
      .with(crash: TelemetryFeature(enabled: true))
      .with(network: TelemetryFeature(enabled: false))
      .build()
    let config = AwsOpenTelemetryConfig(aws: awsConfig, telemetry: telemetryConfig)

    let builder = try! AwsOpenTelemetryRumBuilder.create(config: config)
    let plan = builder.instrumentationPlan

    XCTAssertTrue(plan.sessionEvents)
    XCTAssertFalse(plan.view)
    XCTAssertTrue(plan.crash)
    XCTAssertFalse(plan.network)
  }

  override func tearDown() {
    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
    super.tearDown()
  }
}
