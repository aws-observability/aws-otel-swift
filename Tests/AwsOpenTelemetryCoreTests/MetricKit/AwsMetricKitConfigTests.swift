import XCTest
@testable import AwsOpenTelemetryCore

final class AwsMetricKitConfigTests: XCTestCase {
  func testDefaultConfiguration() {
    let config = AwsMetricKitConfig.default
    XCTAssertEqual(config.crashes, AwsMetricKitConfig.default.crashes)
  }

  func testCustomConfiguration() {
    let config = AwsMetricKitConfig(crashes: false, hangs: false)
    XCTAssertEqual(config.crashes, false)
    XCTAssertEqual(config.hangs, false)
  }

  func testDefaultCrashes() {
    XCTAssertEqual(AwsMetricKitConfig.default.crashes, true)
  }

  func testDefaultHangs() {
    XCTAssertEqual(AwsMetricKitConfig.default.hangs, true)
  }

  func testBuilderPattern() {
    let config = AwsMetricKitConfig.builder()
      .with(crashes: false)
      .with(hangs: false)
      .build()

    XCTAssertEqual(config.crashes, false)
    XCTAssertEqual(config.hangs, false)
  }

  func testBuilderDefaultValues() {
    let config = AwsMetricKitConfig.builder().build()
    XCTAssertEqual(config.crashes, true)
    XCTAssertEqual(config.hangs, true)
  }
}
