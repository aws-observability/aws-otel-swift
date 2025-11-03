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
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(appMonitorId)",
        "rumAlias": "\(alias)",
        "cognitoIdentityPool": "test-pool"
      },
      "exportOverride": {
        "logs": "\(logsEndpoint)",
        "traces": "\(tracesEndpoint)"
      },
      "sessionTimeout": \(sessionTimeout),
      "sessionSampleRate": 1.0,
      "applicationAttributes": {
        "application.version": "\(appVersion)"
      },
      "debug": true,
      "telemetry": {
        "startup": { "enabled": false },
        "sessionEvents": { "enabled": false },
        "crash": { "enabled": false },
        "network": { "enabled": false },
        "hang": { "enabled": false },
        "view": { "enabled": false },
        "view": { "enabled": false },
      }
    }
    """

    let config = try AwsRumConfigReader.parseConfig(from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.aws.region, region)
    XCTAssertEqual(config.aws.rumAppMonitorId, appMonitorId)
    XCTAssertEqual(config.aws.rumAlias, alias)
    XCTAssertEqual(config.exportOverride?.logs, logsEndpoint)
    XCTAssertEqual(config.sessionTimeout, sessionTimeout)
    XCTAssertEqual(config.debug, true)
    XCTAssertEqual(config.applicationAttributes?["application.version"], appVersion)
    XCTAssertFalse(config.telemetry!.startup?.enabled ?? true)
    XCTAssertFalse(config.telemetry!.sessionEvents?.enabled ?? true)
    XCTAssertFalse(config.telemetry!.crash?.enabled ?? true)
    XCTAssertFalse(config.telemetry!.network?.enabled ?? true)
    XCTAssertFalse(config.telemetry!.hang?.enabled ?? true)
    XCTAssertFalse(config.telemetry?.view?.enabled ?? true)
    XCTAssertFalse(config.telemetry?.view?.enabled ?? true)
  }

  func testParseConfigWithDefaults() throws {
    let jsonString = """
    {
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(appMonitorId)"
      },
      "applicationAttributes": {
        "application.version": "\(appVersion)"
      }
    }
    """

    let config = try AwsRumConfigReader.parseConfig(from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.aws.region, region)
    XCTAssertNil(config.debug)
    XCTAssertNil(config.aws.rumAlias)
    XCTAssertNil(config.exportOverride)
    XCTAssertTrue(config.telemetry!.startup?.enabled ?? false)
    XCTAssertTrue(config.telemetry!.sessionEvents?.enabled ?? false)
    XCTAssertTrue(config.telemetry!.crash?.enabled ?? false)
    XCTAssertTrue(config.telemetry!.network?.enabled ?? false)
    XCTAssertTrue(config.telemetry!.hang?.enabled ?? false)
    XCTAssertTrue(config.telemetry?.view?.enabled ?? false)
    XCTAssertTrue(config.telemetry?.view?.enabled ?? false)
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
      "aws": {
        "region": "\(region)"
      },
      "applicationAttributes": {
        "application.version": "\(appVersion)"
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
      "aws": {
        "rumAppMonitorId": "\(appMonitorId)"
      },
      "applicationAttributes": {
        "application.version": "\(appVersion)"
      }
    }
    """

    XCTAssertThrowsError(try AwsRumConfigReader.parseConfig(from: incompleteJson.data(using: .utf8)!)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testParseConfigMissingAws() {
    let incompleteJson = """
    {
      "applicationAttributes": {
        "application.version": "\(appVersion)"
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
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(appMonitorId)",
        "rumAlias": "\(alias)"
      },
      "exportOverride": {
        "logs": "\(logsEndpoint)"
      },
      "debug": true,
      "applicationAttributes": {
        "application.version": "\(appVersion)"
      },
      "telemetry": {
        "startup": { "enabled": false },
        "sessionEvents": { "enabled": false },
        "crash": { "enabled": false },
        "network": { "enabled": false },
        "hang": { "enabled": false },
        "view": { "enabled": false },
        "view": { "enabled": false },
      }
    }
    """

    try jsonString.write(to: tempFileURL, atomically: true, encoding: .utf8)

    let config = AwsRumConfigReader.loadConfig(from: tempFileURL)

    XCTAssertNotNil(config)
    XCTAssertEqual(config?.aws.region, region)
    XCTAssertEqual(config?.debug, true)
    XCTAssertEqual(config?.aws.rumAlias, alias)
    XCTAssertEqual(config?.exportOverride?.logs, logsEndpoint)
    XCTAssertEqual(config?.applicationAttributes?["application.version"], appVersion)
    XCTAssertFalse(config?.telemetry?.startup?.enabled ?? true)
    XCTAssertFalse(config?.telemetry?.sessionEvents?.enabled ?? true)
    XCTAssertFalse(config?.telemetry?.crash?.enabled ?? true)
    XCTAssertFalse(config?.telemetry?.network?.enabled ?? true)
    XCTAssertFalse(config?.telemetry?.hang?.enabled ?? true)
    XCTAssertFalse(config?.telemetry?.view?.enabled ?? true)
    XCTAssertFalse(config?.telemetry?.view?.enabled ?? true)

    try FileManager.default.removeItem(at: tempFileURL)
  }

  func testLoadConfigFromURLWithDefaults() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFileURL = tempDir.appendingPathComponent("config_with_defaults.json")

    let jsonString = """
    {
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(appMonitorId)"
      },
      "applicationAttributes": {
        "application.version": "\(appVersion)"
      }
    }
    """

    try jsonString.write(to: tempFileURL, atomically: true, encoding: .utf8)

    let config = AwsRumConfigReader.loadConfig(from: tempFileURL)

    XCTAssertNotNil(config)
    XCTAssertEqual(config?.aws.region, region)
    XCTAssertNil(config?.debug)
    XCTAssertNil(config?.aws.rumAlias)
    XCTAssertNil(config?.exportOverride)
    XCTAssertEqual(config?.applicationAttributes?["application.version"], appVersion)
    XCTAssertTrue(config?.telemetry?.startup?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.sessionEvents?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.crash?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.network?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.hang?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.view?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.view?.enabled ?? false)

    try FileManager.default.removeItem(at: tempFileURL)
  }

  func testLoadConfigFromURLWithDefaultValues() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFileURL = tempDir.appendingPathComponent("config_default_values.json")

    let jsonString = """
    {
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(appMonitorId)"
      },
      "applicationAttributes": {
        "application.version": "\(appVersion)"
      },
      "telemetry": {
        "startup": { "enabled": true },
        "sessionEvents": { "enabled": true },
        "crash": { "enabled": true },
        "network": { "enabled": true },
        "hang": { "enabled": true },
        "view": { "enabled": true },
        "view": { "enabled": true },
      }
    }
    """

    try jsonString.write(to: tempFileURL, atomically: true, encoding: .utf8)

    let config = AwsRumConfigReader.loadConfig(from: tempFileURL)

    XCTAssertNotNil(config)
    XCTAssertEqual(config?.aws.region, region)
    XCTAssertNil(config?.debug)
    XCTAssertTrue(config?.telemetry?.startup?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.sessionEvents?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.crash?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.network?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.hang?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.view?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.view?.enabled ?? false)

    try FileManager.default.removeItem(at: tempFileURL)
  }

  func testLoadConfigFromInvalidURL() {
    let invalidURL = URL(fileURLWithPath: "/nonexistent/path/config.json")

    let config = AwsRumConfigReader.loadConfig(from: invalidURL)

    XCTAssertNil(config)
  }

  func testParseConfigWithPartialTelemetryOverrides() throws {
    let jsonString = """
    {
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(appMonitorId)"
      },
      "applicationAttributes": {
        "application.version": "\(appVersion)"
      },
      "telemetry": {
        "view": { "enabled": false },
        "crash": { "enabled": false }
      }
    }
    """

    let config = try AwsRumConfigReader.parseConfig(from: jsonString.data(using: .utf8)!)

    // Explicitly set features should be false
    XCTAssertFalse(config.telemetry?.view?.enabled ?? true)
    XCTAssertFalse(config.telemetry!.crash?.enabled ?? true)

    // Unspecified features should default to true
    XCTAssertTrue(config.telemetry!.startup?.enabled ?? false)
    XCTAssertTrue(config.telemetry!.sessionEvents?.enabled ?? false)
    XCTAssertTrue(config.telemetry!.network?.enabled ?? false)
    XCTAssertTrue(config.telemetry!.hang?.enabled ?? false)
  }

  func testLoadConfigWithPartialTelemetryOverrides() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFileURL = tempDir.appendingPathComponent("config_partial_telemetry.json")

    let jsonString = """
    {
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(appMonitorId)"
      },
      "applicationAttributes": {
        "application.version": "\(appVersion)"
      },
      "telemetry": {
        "network": { "enabled": false },
        "view": { "enabled": false }
      }
    }
    """

    try jsonString.write(to: tempFileURL, atomically: true, encoding: .utf8)

    let config = AwsRumConfigReader.loadConfig(from: tempFileURL)

    XCTAssertNotNil(config)

    // Explicitly disabled features
    XCTAssertFalse(config?.telemetry?.network?.enabled ?? true)
    XCTAssertFalse(config?.telemetry?.view?.enabled ?? true)

    // Unspecified features should default to true
    XCTAssertTrue(config?.telemetry?.startup?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.sessionEvents?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.crash?.enabled ?? false)
    XCTAssertTrue(config?.telemetry?.hang?.enabled ?? false)

    try FileManager.default.removeItem(at: tempFileURL)
  }

  // MARK: - loadJsonConfig Tests

  func testLoadJsonConfigFromBundleNotFound() {
    // Test when aws_config.json is not in bundle
    let config = AwsRumConfigReader.loadJsonConfig()

    XCTAssertNil(config)
  }
}
