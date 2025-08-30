import XCTest
@testable import AwsOpenTelemetryCore

final class AwsOpenTelemetryRumBuilderInstrumentationTests: XCTestCase {
  func testBuilderUsesInstrumentationPlan() {
    let awsConfig = AwsConfig(region: "us-west-2", rumAppMonitorId: "test-id")
    let telemetryConfig = TelemetryConfig.builder()
      .with(sessionEvents: TelemetryFeature(enabled: true))
      .with(view: TelemetryFeature(enabled: true))
      .with(crash: TelemetryFeature(enabled: true))
      .with(hang: TelemetryFeature(enabled: false))
      .with(network: TelemetryFeature(enabled: true))
      .build()
    let config = AwsOpenTelemetryConfig(aws: awsConfig, telemetry: telemetryConfig)

    let builder = try! AwsOpenTelemetryRumBuilder.create(config: config)
    let plan = builder.instrumentationPlan

    XCTAssertTrue(plan.sessionEvents)
    XCTAssertTrue(plan.view)
    XCTAssertTrue(plan.crash)
    XCTAssertFalse(plan.hang)
    XCTAssertTrue(plan.network)
    XCTAssertEqual(plan.urlSessionConfig?.region, "us-west-2")
    XCTAssertNil(plan.urlSessionConfig?.exportOverride)
    XCTAssertEqual(plan.metricKitConfig?.crashes, true)
    XCTAssertEqual(plan.metricKitConfig?.hangs, false)
  }

  override func tearDown() {
    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
    super.tearDown()
  }
}
