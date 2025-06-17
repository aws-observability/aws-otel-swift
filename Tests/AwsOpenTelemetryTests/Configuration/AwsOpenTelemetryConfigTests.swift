import XCTest
@testable import AwsOpenTelemetryCore

final class AwsOpenTelemetryConfigTests: XCTestCase {
  // Define test values
  let version = "1.0.0"
  let region = "us-west-2"
  let appMonitorId = "test-monitor-id"
  let appVersion = "1.2.3"
  let logsEndpoint = "https://custom-logs.example.com"
  let tracesEndpoint = "https://custom-traces.example.com"
  let tracesOnlyEndpoint = "https://traces-only.example.com"
  let debug = true
  let defaultVersion = "1.0.0"
  let alias = "test-alias"

  func testConfigInitialization() {
    // Test basic initialization
    let config = AwsOpenTelemetryConfig(
      version: version,
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.appMonitorId, appMonitorId)
    XCTAssertNil(config.rum.overrideEndpoint)
    XCTAssertNil(config.rum.alias)
    XCTAssertEqual(config.rum.debug, false)
    XCTAssertEqual(config.application.applicationVersion, appVersion)
  }

  func testConfigWithOptionalFields() {
    // Test initialization with all optional fields
    let endpointOverrides = EndpointOverrides(
      logs: logsEndpoint,
      traces: tracesEndpoint
    )

    let config = AwsOpenTelemetryConfig(
      version: version,
      rum: RumConfig(
        region: region,
        appMonitorId: appMonitorId,
        overrideEndpoint: endpointOverrides,
        debug: debug,
        alias: alias
      ),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.appMonitorId, appMonitorId)
    XCTAssertNotNil(config.rum.overrideEndpoint)
    XCTAssertNotNil(config.rum.alias)
    XCTAssertEqual(config.rum.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(config.rum.overrideEndpoint?.traces, tracesEndpoint)
    XCTAssertEqual(config.rum.alias, alias)
    XCTAssertEqual(config.rum.debug, debug)
    XCTAssertEqual(config.application.applicationVersion, appVersion)
  }

  func testDefaultVersionValue() {
    // Test that version defaults to "1.0.0" when not provided
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    XCTAssertEqual(config.version, defaultVersion)
  }

  func testEndpointOverridesInitialization() {
    // Test EndpointOverrides initialization
    let overrides = EndpointOverrides(logs: logsEndpoint, traces: tracesEndpoint)

    XCTAssertEqual(overrides.logs, logsEndpoint)
    XCTAssertEqual(overrides.traces, tracesEndpoint)

    // Test with nil values
    let partialOverrides = EndpointOverrides(logs: nil, traces: tracesOnlyEndpoint)

    XCTAssertNil(partialOverrides.logs)
    XCTAssertEqual(partialOverrides.traces, tracesOnlyEndpoint)
  }

  func testCodable() throws {
    // Create a config
    let originalConfig = AwsOpenTelemetryConfig(
      version: version,
      rum: RumConfig(
        region: region,
        appMonitorId: appMonitorId,
        overrideEndpoint: EndpointOverrides(
          logs: logsEndpoint,
          traces: tracesEndpoint
        ),
        debug: debug
      ),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Encode to JSON
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(originalConfig)

    // Decode back
    let decoder = JSONDecoder()
    let decodedConfig = try decoder.decode(AwsOpenTelemetryConfig.self, from: jsonData)

    // Verify all properties match
    XCTAssertEqual(decodedConfig.version, version)
    XCTAssertEqual(decodedConfig.rum.region, region)
    XCTAssertEqual(decodedConfig.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(decodedConfig.rum.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(decodedConfig.rum.overrideEndpoint?.traces, tracesEndpoint)
    XCTAssertEqual(decodedConfig.rum.debug, debug)
    XCTAssertEqual(decodedConfig.application.applicationVersion, appVersion)
  }
}
