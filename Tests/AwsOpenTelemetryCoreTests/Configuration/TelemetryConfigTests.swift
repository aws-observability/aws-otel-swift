import XCTest
@testable import AwsOpenTelemetryCore

final class TelemetryConfigTests: XCTestCase {
  func testTelemetryConfigDefaultInit() {
    let config = TelemetryConfig()
    XCTAssertEqual(config.startup?.enabled, true)
    XCTAssertEqual(config.view?.enabled, true)
    XCTAssertEqual(config.crash?.enabled, true)
    XCTAssertEqual(config.network?.enabled, true)
    XCTAssertEqual(config.sessionEvents?.enabled, true)
    XCTAssertEqual(config.hang?.enabled, true)
  }

  func testTelemetryFeatureInit() {
    let enabledFeature = TelemetryFeature(enabled: true)
    let disabledFeature = TelemetryFeature(enabled: false)

    XCTAssertTrue(enabledFeature.enabled)
    XCTAssertFalse(disabledFeature.enabled)
  }

  func testTelemetryConfigDefault() {
    let config = TelemetryConfig.default

    XCTAssertEqual(config.startup?.enabled, true)
    XCTAssertEqual(config.view?.enabled, true)
    XCTAssertEqual(config.crash?.enabled, true)
    XCTAssertEqual(config.network?.enabled, true)
  }

  func testTelemetryConfigBuilder() {
    let config = TelemetryConfig.builder()
      .with(startup: TelemetryFeature(enabled: false))
      .with(view: TelemetryFeature(enabled: true))
      .with(crash: TelemetryFeature(enabled: false))
      .build()

    XCTAssertEqual(config.startup?.enabled, false)
    XCTAssertEqual(config.view?.enabled, true)
    XCTAssertEqual(config.crash?.enabled, false)
  }
}
