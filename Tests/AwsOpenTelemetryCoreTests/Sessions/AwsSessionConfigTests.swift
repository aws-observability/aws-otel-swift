import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionConfigTests: XCTestCase {
  func testDefaultConfiguration() {
    let config = AwsSessionConfig.default
    XCTAssertEqual(config.sessionTimeout, AwsSessionConfig.default.sessionTimeout)
  }

  func testCustomConfiguration() {
    let customTimeout = 3600
    let config = AwsSessionConfig(sessionTimeout: customTimeout)
    XCTAssertEqual(config.sessionTimeout, customTimeout)
  }

  func testDefaultSessionTimeout() {
    XCTAssertEqual(AwsSessionConfig.default.sessionTimeout, 30 * 60)
  }

  func testBuilderPattern() {
    let config = AwsSessionConfig.builder()
      .with(sessionTimeout: 45 * 60)
      .build()

    XCTAssertEqual(config.sessionTimeout, 45 * 60)
  }

  func testBuilderDefaultValues() {
    let config = AwsSessionConfig.builder().build()
    XCTAssertEqual(config.sessionTimeout, 30 * 60)
  }
}
