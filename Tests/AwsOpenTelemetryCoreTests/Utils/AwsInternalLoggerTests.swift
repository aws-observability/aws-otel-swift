import XCTest
@testable import AwsOpenTelemetryCore

final class AwsInternalLoggerTests: XCTestCase {
  func testLoggingWhenDebugEnabled() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-east-1", rumAppMonitorId: "test-id"),
      debug: true
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    AwsInternalLogger.debug("Test debug")
    AwsInternalLogger.info("Test info")
    AwsInternalLogger.warning("Test warning")
    AwsInternalLogger.error("Test error")
  }

  func testLoggingWhenDebugDisabled() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-east-1", rumAppMonitorId: "test-id"),
      debug: false
    )
    AwsOpenTelemetryAgent.shared.configuration = config

    AwsInternalLogger.debug("Test debug")
    AwsInternalLogger.info("Test info")
    AwsInternalLogger.warning("Test warning")
    AwsInternalLogger.error("Test error")
  }

  func testLoggingWhenConfigDoesNotExist() {
    AwsOpenTelemetryAgent.shared.configuration = nil

    AwsInternalLogger.debug("Test debug")
    AwsInternalLogger.info("Test info")
    AwsInternalLogger.warning("Test warning")
    AwsInternalLogger.error("Test error")
  }
}
