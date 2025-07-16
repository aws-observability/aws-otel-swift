import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionConfigurationTests: XCTestCase {
  func testDefaultConfiguration() {
    let config = AwsSessionConfiguration.default
    XCTAssertEqual(config.sessionTimeout, AwsSessionConfiguration.default.sessionTimeout)
  }

  func testCustomConfiguration() {
    let customTimeout = 3600
    let config = AwsSessionConfiguration(sessionTimeout: customTimeout)
    XCTAssertEqual(config.sessionTimeout, customTimeout)
  }

  func testDefaultSessionTimeout() {
    XCTAssertEqual(AwsSessionConfiguration.default.sessionTimeout, 30 * 60)
  }
}
