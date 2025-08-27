import XCTest
@testable import AwsOpenTelemetryCore

final class AwsRumConfigReaderTests: XCTestCase {
  let version = "1.0.0"
  let region = "us-west-2"
  let appMonitorId = "test-monitor-id"
  let appVersion = "1.2.3"
  let logsEndpoint = "https://logs.example.com"
  let tracesEndpoint = "https://traces.example.com"
  let alias = "test-alias"
  let sessionTimeout: Int = 300

  // MARK: - parseConfig Tests

  func testParseConfigWithOverrides() throws {
    let jsonString = """
    {
      "version": "\(version)",
      "rum": {
        "region": "\(region)",
        "appMonitorId": "\(appMonitorId)",
        "debug": true,
        "alias": "\(alias)",
        "sessionTimeout": \(sessionTimeout),
        "crashes": false,
        "overrideEndpoint": {
          "logs": "\(logsEndpoint)",
          "traces": "\(tracesEndpoint)"
        }
      },
      "application": {
        "applicationVersion": "\(appVersion)"
      },
      "telemetry": {
        "isUiKitViewInstrumentationEnabled": false
      }
    }
    """

    let config = try AwsRumConfigReader.parseConfig(from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.debug, true)
    XCTAssertEqual(config.rum.alias, alias)
    XCTAssertEqual(config.rum.crashes, false)
    XCTAssertEqual(config.rum.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(config.application.applicationVersion, appVersion)
    XCTAssertFalse(config.telemetry!.isUiKitViewInstrumentationEnabled)
  }

  func testParseConfigWithDefaults() throws {
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

    let config = try AwsRumConfigReader.parseConfig(from: jsonString.data(using: .utf8)!)

    XCTAssertNil(config.version)
    XCTAssertEqual(config.rum.debug, false)
    XCTAssertNil(config.rum.alias)
    XCTAssertEqual(config.rum.crashes, true)
    XCTAssertNil(config.rum.overrideEndpoint)
    XCTAssertTrue(config.telemetry!.isUiKitViewInstrumentationEnabled)
  }

  func testParseConfigInvalidJSON() {
    let invalidJson = "{ this is not valid JSON }"
    let data = invalidJson.data(using: .utf8)!

    XCTAssertThrowsError(try AwsRumConfigReader.parseConfig(from: data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testParseConfigMissingAppMonitorId() {
    let incompleteJson = """
    {
      "rum": {
        "region": "\(region)"
      },
      "application": {
        "applicationVersion": "\(appVersion)"
      }
    }
    """

    XCTAssertThrowsError(try AwsRumConfigReader.parseConfig(from: incompleteJson.data(using: .utf8)!)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testParseConfigMissingRegion() {
    let incompleteJson = """
    {
      "rum": {
        "appMonitorId": "\(appMonitorId)"
      },
      "application": {
        "applicationVersion": "\(appVersion)"
      }
    }
    """

    XCTAssertThrowsError(try AwsRumConfigReader.parseConfig(from: incompleteJson.data(using: .utf8)!)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testParseConfigMissingApplication() {
    let incompleteJson = """
    {
      "rum": {
        "region": "\(region)",
        "appMonitorId": "\(appMonitorId)"
      }
    }
    """

    XCTAssertThrowsError(try AwsRumConfigReader.parseConfig(from: incompleteJson.data(using: .utf8)!)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  // MARK: - loadConfig(from:) Tests

  func testLoadConfigFromURLWithValues() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFileURL = tempDir.appendingPathComponent("config_with_values.json")

    let jsonString = """
    {
      "version": "\(version)",
      "rum": {
        "region": "\(region)",
        "appMonitorId": "\(appMonitorId)",
        "debug": true,
        "alias": "\(alias)",
        "crashes": false,
        "overrideEndpoint": {
          "logs": "\(logsEndpoint)"
        }
      },
      "application": {
        "applicationVersion": "\(appVersion)"
      }
    }
    """

    try jsonString.write(to: tempFileURL, atomically: true, encoding: .utf8)

    let config = AwsRumConfigReader.loadConfig(from: tempFileURL)

    XCTAssertNotNil(config)
    XCTAssertEqual(config?.version, version)
    XCTAssertEqual(config?.rum.debug, true)
    XCTAssertEqual(config?.rum.alias, alias)
    XCTAssertEqual(config?.rum.crashes, false)
    XCTAssertEqual(config?.rum.overrideEndpoint?.logs, logsEndpoint)

    try FileManager.default.removeItem(at: tempFileURL)
  }

  func testLoadConfigFromURLWithDefaults() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFileURL = tempDir.appendingPathComponent("config_with_defaults.json")

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

    try jsonString.write(to: tempFileURL, atomically: true, encoding: .utf8)

    let config = AwsRumConfigReader.loadConfig(from: tempFileURL)

    XCTAssertNotNil(config)
    XCTAssertNil(config?.version)
    XCTAssertEqual(config?.rum.debug, false)
    XCTAssertNil(config?.rum.alias)
    XCTAssertEqual(config?.rum.crashes, true)
    XCTAssertNil(config?.rum.overrideEndpoint)

    try FileManager.default.removeItem(at: tempFileURL)
  }

  func testLoadConfigFromURLWithDefaultValues() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFileURL = tempDir.appendingPathComponent("config_default_values.json")

    let jsonString = """
    {
      "version": "1.0.0",
      "rum": {
        "region": "\(region)",
        "appMonitorId": "\(appMonitorId)"
      },
      "application": {
        "applicationVersion": "\(appVersion)"
      },
      "telemetry": {
        "isUiKitViewInstrumentationEnabled": true
      }
    }
    """

    try jsonString.write(to: tempFileURL, atomically: true, encoding: .utf8)

    let config = AwsRumConfigReader.loadConfig(from: tempFileURL)

    XCTAssertNotNil(config)
    XCTAssertEqual(config?.version, "1.0.0")
    XCTAssertEqual(config?.rum.debug, false)
    XCTAssertEqual(config?.rum.crashes, true)
    XCTAssertTrue(config?.telemetry?.isUiKitViewInstrumentationEnabled ?? false)

    try FileManager.default.removeItem(at: tempFileURL)
  }

  func testLoadConfigFromInvalidURL() {
    let invalidURL = URL(fileURLWithPath: "/nonexistent/path/config.json")

    let config = AwsRumConfigReader.loadConfig(from: invalidURL)

    XCTAssertNil(config)
  }

  // MARK: - loadJsonConfig Tests

  func testLoadJsonConfigFromBundleNotFound() {
    // Test when aws_config.json is not in bundle
    let config = AwsRumConfigReader.loadJsonConfig()

    XCTAssertNil(config)
  }
}
