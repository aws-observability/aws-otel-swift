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
  let alias = "test-alias"
  let sessionTimeout: NSNumber = 100

  // MARK: - AwsOpenTelemetryConfig Tests

  func testAwsOpenTelemetryConfigManualInitWithValues() {
    let config = AwsOpenTelemetryConfig(
      version: version,
      rum: RumConfig(region: region, appMonitorId: appMonitorId, debug: true, crashes: false),
      application: ApplicationConfig(applicationVersion: appVersion),
      telemetry: TelemetryConfig(isUiKitViewInstrumentationEnabled: false)
    )

    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.crashes, false)
    XCTAssertEqual(config.application.applicationVersion, appVersion)
    XCTAssertFalse(config.telemetry!.isUiKitViewInstrumentationEnabled)
  }

  func testAwsOpenTelemetryConfigManualInitWithDefaults() {
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    XCTAssertEqual(config.version, "1.0.0")
    XCTAssertEqual(config.rum.crashes, true)
    XCTAssertTrue(config.telemetry!.isUiKitViewInstrumentationEnabled)
  }

  func testAwsOpenTelemetryConfigJSONDecoderWithValues() throws {
    let jsonString = """
    {
      "version": "\(version)",
      "rum": {
        "region": "\(region)",
        "appMonitorId": "\(appMonitorId)",
        "debug": true,
        "crashes": false
      },
      "application": {
        "applicationVersion": "\(appVersion)"
      },
      "telemetry": {
        "isUiKitViewInstrumentationEnabled": false
      }
    }
    """

    let config = try JSONDecoder().decode(AwsOpenTelemetryConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.debug, true)
    XCTAssertEqual(config.rum.crashes, false)
    XCTAssertFalse(config.telemetry!.isUiKitViewInstrumentationEnabled)
  }

  func testAwsOpenTelemetryConfigJSONDecoderWithDefaults() throws {
    let jsonString = """
    {
      "rum": {
        "region": "\(region)",
        "appMonitorId": "\(appMonitorId)"
      },
      "application": {
        "applicationVersion": "\(appVersion)"
      }
    }
    """

    let config = try JSONDecoder().decode(AwsOpenTelemetryConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertNil(config.version)
    XCTAssertEqual(config.rum.debug, false)
    XCTAssertEqual(config.rum.crashes, true)
    XCTAssertTrue(config.telemetry!.isUiKitViewInstrumentationEnabled)
  }

  // MARK: - RumConfig Tests

  func testRumConfigObjectiveCInitWithValues() {
    let config = RumConfig(
      region: region,
      appMonitorId: appMonitorId,
      overrideEndpoint: EndpointOverrides(logs: logsEndpoint, traces: tracesEndpoint),
      debug: true,
      alias: alias,
      sessionTimeout: sessionTimeout,
      crashes: false
    )

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.appMonitorId, appMonitorId)
    XCTAssertEqual(config.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(config.debug, true)
    XCTAssertEqual(config.alias, alias)
    XCTAssertEqual(config.crashes, false)
  }

  func testRumConfigObjectiveCInitWithDefaults() {
    let config = RumConfig(region: region, appMonitorId: appMonitorId)

    XCTAssertNil(config.overrideEndpoint)
    XCTAssertEqual(config.debug, false)
    XCTAssertNil(config.alias)
    XCTAssertEqual(config.crashes, true)
    XCTAssertNotNil(config.sessionTimeout)
  }

  func testRumConfigSwiftOnlyInitWithValues() {
    let config = RumConfig(
      region: region,
      appMonitorId: appMonitorId,
      overrideEndpoint: EndpointOverrides(logs: logsEndpoint),
      debug: true,
      alias: alias,
      sessionTimeout: sessionTimeout,
      crashes: false,
      _swiftOnly: nil
    )

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.debug, true)
    XCTAssertEqual(config.crashes, false)
  }

  func testRumConfigSwiftOnlyInitWithNils() {
    let config = RumConfig(
      region: region,
      appMonitorId: appMonitorId,
      debug: nil,
      crashes: nil,
      _swiftOnly: nil
    )

    XCTAssertEqual(config.debug, false)
    XCTAssertEqual(config.crashes, true)
  }

  func testRumConfigJSONDecoderWithValues() throws {
    let jsonString = """
    {
      "region": "\(region)",
      "appMonitorId": "\(appMonitorId)",
      "debug": true,
      "alias": "\(alias)",
      "crashes": false,
      "sessionTimeout": 300
    }
    """

    let config = try JSONDecoder().decode(RumConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.debug, true)
    XCTAssertEqual(config.alias, alias)
    XCTAssertEqual(config.crashes, false)
    XCTAssertEqual(config.sessionTimeout, 300)
  }

  func testRumConfigJSONDecoderWithDefaults() throws {
    let jsonString = """
    {
      "region": "\(region)",
      "appMonitorId": "\(appMonitorId)"
    }
    """

    let config = try JSONDecoder().decode(RumConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.debug, false)
    XCTAssertNil(config.alias)
    XCTAssertEqual(config.crashes, true)
    XCTAssertNotNil(config.sessionTimeout)
  }

  // MARK: - ApplicationConfig Tests

  func testApplicationConfigInit() {
    let config = ApplicationConfig(applicationVersion: appVersion)
    XCTAssertEqual(config.applicationVersion, appVersion)
  }

  // MARK: - TelemetryConfig Tests

  func testTelemetryConfigDefaultInit() {
    let config = TelemetryConfig()
    XCTAssertTrue(config.isUiKitViewInstrumentationEnabled)
  }

  func testTelemetryConfigCustomInit() {
    let enabledConfig = TelemetryConfig(isUiKitViewInstrumentationEnabled: true)
    let disabledConfig = TelemetryConfig(isUiKitViewInstrumentationEnabled: false)

    XCTAssertTrue(enabledConfig.isUiKitViewInstrumentationEnabled)
    XCTAssertFalse(disabledConfig.isUiKitViewInstrumentationEnabled)
  }

  // MARK: - EndpointOverrides Tests

  func testEndpointOverridesInitWithValues() {
    let overrides = EndpointOverrides(logs: logsEndpoint, traces: tracesEndpoint)

    XCTAssertEqual(overrides.logs, logsEndpoint)
    XCTAssertEqual(overrides.traces, tracesEndpoint)
  }

  func testEndpointOverridesInitWithDefaults() {
    let overrides = EndpointOverrides()

    XCTAssertNil(overrides.logs)
    XCTAssertNil(overrides.traces)
  }
}
