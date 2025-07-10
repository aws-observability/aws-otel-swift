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
  let debug = true
  let alias = "test-alias"

  func testBasicConfigInitialization() {
    // Test basic initialization with defaults
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    XCTAssertEqual(config.version, "1.0.0") // Default version
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.appMonitorId, appMonitorId)
    XCTAssertNil(config.rum.overrideEndpoint)
    XCTAssertNil(config.rum.alias)
    XCTAssertEqual(config.rum.debug, false)
    XCTAssertEqual(config.application.applicationVersion, appVersion)

    // Test default telemetry configuration
    XCTAssertTrue(config.telemetry.isUiKitViewInstrumentationEnabled, "UIKit instrumentation should be enabled by default")
  }

  func testFullConfigInitialization() {
    // Test initialization with all optional fields
    let config = AwsOpenTelemetryConfig(
      version: version,
      rum: RumConfig(
        region: region,
        appMonitorId: appMonitorId,
        overrideEndpoint: EndpointOverrides(logs: logsEndpoint, traces: tracesEndpoint),
        debug: debug,
        alias: alias
      ),
      application: ApplicationConfig(applicationVersion: appVersion),
      telemetry: TelemetryConfig(isUiKitViewInstrumentationEnabled: false)
    )

    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(config.rum.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(config.rum.overrideEndpoint?.traces, tracesEndpoint)
    XCTAssertEqual(config.rum.alias, alias)
    XCTAssertEqual(config.rum.debug, debug)
    XCTAssertEqual(config.application.applicationVersion, appVersion)
    XCTAssertFalse(config.telemetry.isUiKitViewInstrumentationEnabled, "Custom telemetry config should be respected")
  }

  func testTelemetryConfigVariations() {
    // Test TelemetryConfig standalone and integration
    let defaultTelemetry = TelemetryConfig()
    let disabledTelemetry = TelemetryConfig(isUiKitViewInstrumentationEnabled: false)

    XCTAssertTrue(defaultTelemetry.isUiKitViewInstrumentationEnabled)
    XCTAssertFalse(disabledTelemetry.isUiKitViewInstrumentationEnabled)

    // Test integration with main config
    let configWithDisabled = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion),
      telemetry: disabledTelemetry
    )

    XCTAssertFalse(configWithDisabled.telemetry.isUiKitViewInstrumentationEnabled)
  }

  func testJSONSerialization() throws {
    // Test complete JSON serialization including telemetry
    let originalConfig = AwsOpenTelemetryConfig(
      version: version,
      rum: RumConfig(
        region: region,
        appMonitorId: appMonitorId,
        overrideEndpoint: EndpointOverrides(logs: logsEndpoint, traces: tracesEndpoint),
        debug: debug
      ),
      application: ApplicationConfig(applicationVersion: appVersion),
      telemetry: TelemetryConfig(isUiKitViewInstrumentationEnabled: false)
    )

    // Encode and decode
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(originalConfig)
    let decoder = JSONDecoder()
    let decodedConfig = try decoder.decode(AwsOpenTelemetryConfig.self, from: jsonData)

    // Verify all properties including telemetry
    XCTAssertEqual(decodedConfig.version, version)
    XCTAssertEqual(decodedConfig.rum.region, region)
    XCTAssertEqual(decodedConfig.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(decodedConfig.rum.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(decodedConfig.rum.overrideEndpoint?.traces, tracesEndpoint)
    XCTAssertEqual(decodedConfig.rum.debug, debug)
    XCTAssertEqual(decodedConfig.application.applicationVersion, appVersion)
    XCTAssertFalse(decodedConfig.telemetry.isUiKitViewInstrumentationEnabled)
  }

  func testJSONWithMissingTelemetry() throws {
    // Test that telemetry defaults when missing from JSON
    let jsonString = """
    {
      "version": "1.0.0",
      "rum": {
        "region": "us-west-2",
        "appMonitorId": "test-monitor"
      },
      "application": {
        "applicationVersion": "1.0.0"
      }
    }
    """

    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let config = try decoder.decode(AwsOpenTelemetryConfig.self, from: jsonData)

    // Should use default telemetry config when not present in JSON
    XCTAssertTrue(config.telemetry.isUiKitViewInstrumentationEnabled, "Should default to enabled when telemetry not in JSON")
  }

  func testEndpointOverrides() {
    // Test EndpointOverrides variations
    let fullOverrides = EndpointOverrides(logs: logsEndpoint, traces: tracesEndpoint)
    let partialOverrides = EndpointOverrides(logs: nil, traces: tracesEndpoint)

    XCTAssertEqual(fullOverrides.logs, logsEndpoint)
    XCTAssertEqual(fullOverrides.traces, tracesEndpoint)
    XCTAssertNil(partialOverrides.logs)
    XCTAssertEqual(partialOverrides.traces, tracesEndpoint)
  }
}
