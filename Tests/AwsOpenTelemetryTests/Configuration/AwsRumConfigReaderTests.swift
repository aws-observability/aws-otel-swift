import XCTest
@testable import AwsOpenTelemetryCore

final class AwsRumConfigReaderTests: XCTestCase {
  let version = "1.0.0"
  let region = "us-west-2"
  let appMonitorId = "test-monitor-id"
  let debug = true
  let appVersion = "1.2.3"
  let logsEndpoint = "https://logs.example.com"
  let tracesEndpoint = "https://traces.example.com"
  let alias = "test-alias"

  func testParseValidConfig() throws {
    // Create a valid JSON configuration
    let jsonString = """
    {
        "version": "\(version)",
        "rum": {
            "region": "\(region)",
            "appMonitorId": "\(appMonitorId)",
            "debug": \(debug)
        },
        "application": {
            "applicationVersion": "\(appVersion)"
        }
    }
    """

    let data = jsonString.data(using: .utf8)!

    // Parse the configuration
    let config = try AwsRumConfigReader.parseConfig(from: data)

    // Verify the parsed configuration
    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(config.rum.debug, debug)
    XCTAssertEqual(config.application.applicationVersion, appVersion)
  }

  func testParseConfigWithEndpointOverrides() throws {
    // Create a JSON configuration with endpoint overrides
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

    let data = jsonString.data(using: .utf8)!

    // Parse the configuration
    let config = try AwsRumConfigReader.parseConfig(from: data)

    // Verify the endpoint overrides
    XCTAssertEqual(config.rum.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(config.rum.overrideEndpoint?.traces, tracesEndpoint)
  }

    func testParseConfigWithAlias() throws {
      // Create a valid JSON configuration
      let jsonString = """
      {
          "version": "\(version)",
          "rum": {
              "region": "\(region)",
              "appMonitorId": "\(appMonitorId)",
              "alias": "\(alias)"
          },
          "application": {
              "applicationVersion": "\(appVersion)"
          }
      }
      """

      let data = jsonString.data(using: .utf8)!

      // Parse the configuration
      let config = try AwsRumConfigReader.parseConfig(from: data)

      // Verify the alias
        XCTAssertEqual(config.rum.alias, alias)
    }

    
    
  func testParseInvalidJson() {
    // Define test value
    let invalidJson = "{ this is not valid JSON }"
    let data = invalidJson.data(using: .utf8)!

    // Attempt to parse the invalid JSON
    XCTAssertThrowsError(try AwsRumConfigReader.parseConfig(from: data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testParseIncompleteConfig() {
    // Create incomplete JSON (missing required fields)
    let incompleteJson = """
    {
        "version": "\(version)",
        "rum": {
            "region": "\(region)"
            // Missing appMonitorId
        },
        "application": {
            "applicationVersion": "\(appVersion)"
        }
    }
    """

    let data = incompleteJson.data(using: .utf8)!

    // Attempt to parse the incomplete JSON
    XCTAssertThrowsError(try AwsRumConfigReader.parseConfig(from: data)) { error in
      XCTAssertTrue(error is DecodingError)
    }
  }

  func testLoadConfigFromURL() throws {
    // Create a temporary JSON file
    let tempDir = FileManager.default.temporaryDirectory
    let tempFileURL = tempDir.appendingPathComponent("test_config.json")

    let jsonString = """
    {
        "version": "\(version)",
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

    // Load the configuration from the URL
    let config = AwsRumConfigReader.loadConfig(from: tempFileURL)

    // Verify the configuration was loaded correctly
    XCTAssertNotNil(config)
    XCTAssertEqual(config?.rum.region, region)
    XCTAssertEqual(config?.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(config?.application.applicationVersion, appVersion)

    // Clean up
    try FileManager.default.removeItem(at: tempFileURL)
  }

  func testLoadConfigFromInvalidURL() {
    // Define test value
    let invalidURL = URL(fileURLWithPath: "/path/that/does/not/exist.json")

    // Attempt to load the configuration
    let config = AwsRumConfigReader.loadConfig(from: invalidURL)

    // Verify the configuration is nil
    XCTAssertNil(config)
  }
}
