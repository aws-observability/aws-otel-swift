import XCTest
@testable import AwsOpenTelemetryCore

final class AwsOpenTelemetryTests: XCTestCase {
  // Define test values
  let version = "1.0.0"
  let region = "us-west-2"
  let appMonitorId = "test-monitor-id"
  let appVersion = "1.0.0"
  let logsEndpoint = "https://example.com/logs"
  let tracesEndpoint = "https://example.com/traces"

  // Reset the shared instance state between tests
  override func tearDown() {
    // Reset the shared instance state directly for testing purposes
    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
    super.tearDown()
  }

  func testManualInitialization() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: .init(region: region, appMonitorId: appMonitorId),
      application: .init(applicationVersion: appVersion)
    )

    // Initialize the SDK
    let result = AwsOpenTelemetryAgent.shared.initialize(config: config)

    // Verify initialization was successful
    XCTAssertTrue(result)
    XCTAssertTrue(AwsOpenTelemetryAgent.shared.isInitialized)
    XCTAssertNotNil(AwsOpenTelemetryAgent.shared.configuration)
    XCTAssertEqual(AwsOpenTelemetryAgent.shared.configuration?.rum.region, region)
    XCTAssertEqual(AwsOpenTelemetryAgent.shared.configuration?.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(AwsOpenTelemetryAgent.shared.configuration?.application.applicationVersion, appVersion)
  }

  func testDoubleInitialization() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: .init(region: region, appMonitorId: appMonitorId),
      application: .init(applicationVersion: appVersion)
    )

    // First initialization should succeed
    let firstResult = AwsOpenTelemetryAgent.shared.initialize(config: config)
    XCTAssertTrue(firstResult)

    // Second initialization should fail
    let secondResult = AwsOpenTelemetryAgent.shared.initialize(config: config)
    XCTAssertFalse(secondResult)
  }

  func testConfigParsing() throws {
    // Create a JSON string with valid configuration
    let jsonString = """
    {
        "version": "\(version)",
        "rum": {
            "region": "\(region)",
            "appMonitorId": "\(appMonitorId)",
            "overrideEndpoint": {
                "logs": "\(logsEndpoint)",
                "traces": "\(tracesEndpoint)"
            }
        },
        "application": {
            "applicationVersion": "\(appVersion)"
        }
    }
    """

    // Parse the configuration
    let data = jsonString.data(using: .utf8)!
    let config = try AwsRumConfigReader.parseConfig(from: data)

    // Verify the parsed configuration
    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(config.rum.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(config.rum.overrideEndpoint?.traces, tracesEndpoint)
    XCTAssertEqual(config.application.applicationVersion, appVersion)
  }
}
