import XCTest
@testable import AwsOpenTelemetryCore

final class AwsMetricKitConfigTests: XCTestCase {
  func testDefaultConfiguration() {
    let config = AwsMetricKitConfig.default
    XCTAssertEqual(config.crashes, AwsMetricKitConfig.default.crashes)
  }

  func testCustomConfiguration() {
    let config = AwsMetricKitConfig(crashes: false)
    XCTAssertEqual(config.crashes, false)
  }

  func testDefaultCrashes() {
    XCTAssertEqual(AwsMetricKitConfig.default.crashes, true)
  }

  func testBuilderPattern() {
    let config = AwsMetricKitConfig.builder()
      .with(crashes: false)
      .build()

    XCTAssertEqual(config.crashes, false)
  }

  func testBuilderDefaultValues() {
    let config = AwsMetricKitConfig.builder().build()
    XCTAssertEqual(config.crashes, true)
  }
}
