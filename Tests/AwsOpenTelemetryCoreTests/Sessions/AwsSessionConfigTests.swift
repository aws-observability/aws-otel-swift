import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionConfigTests: XCTestCase {
  func testDefaultConfiguration() {
    let config = AwsSessionConfig.default
    XCTAssertEqual(config.sessionTimeout, AwsSessionConfig.default.sessionTimeout)
    XCTAssertEqual(config.sessionSampleRate, 1.0)
  }

  func testCustomConfiguration() {
    let customTimeout = 3600
    let customSampleRate = 0.5
    let config = AwsSessionConfig(sessionTimeout: customTimeout, sessionSampleRate: customSampleRate)
    XCTAssertEqual(config.sessionTimeout, customTimeout)
    XCTAssertEqual(config.sessionSampleRate, customSampleRate)
  }

  func testDefaultSessionTimeout() {
    XCTAssertEqual(AwsSessionConfig.default.sessionTimeout, 30 * 60)
  }

  func testBuilderPattern() {
    let config = AwsSessionConfig.builder()
      .with(sessionTimeout: 45 * 60)
      .with(sessionSampleRate: 0.8)
      .build()

    XCTAssertEqual(config.sessionTimeout, 45 * 60)
    XCTAssertEqual(config.sessionSampleRate, 0.8)
  }

  func testBuilderDefaultValues() {
    let config = AwsSessionConfig.builder().build()
    XCTAssertEqual(config.sessionTimeout, 30 * 60)
    XCTAssertEqual(config.sessionSampleRate, 1.0)
  }

  func testSessionSampleRateBuilder() {
    let config = AwsSessionConfig.builder()
      .with(sessionSampleRate: 0.25)
      .build()

    XCTAssertEqual(config.sessionSampleRate, 0.25)
    XCTAssertEqual(config.sessionTimeout, 30 * 60) // Should keep default
  }
}
