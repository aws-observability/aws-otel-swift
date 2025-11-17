import XCTest
@testable import AwsOpenTelemetryCore

final class AwsOpenTelemetryConfigTests: XCTestCase {
  let region = "us-west-2"
  let rumAppMonitorId = "test-monitor-id"
  let rumAlias = "test-alias"

  let logsEndpoint = "https://custom-logs.example.com"
  let tracesEndpoint = "https://custom-traces.example.com"
  let sessionTimeout = 100
  let sessionSampleRate = 1.0

  func testAwsOpenTelemetryConfigManualInitWithValues() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: rumAppMonitorId, rumAlias: rumAlias)
    let exportOverride = AwsExportOverride(logs: logsEndpoint, traces: tracesEndpoint)
    let otelResourceAttributes = ["service.version": "1.0.0"]
    let telemetryConfig = AwsTelemetryConfig()

    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      sessionTimeout: sessionTimeout,
      sessionSampleRate: sessionSampleRate,
      otelResourceAttributes: otelResourceAttributes,
      debug: true,
      telemetry: telemetryConfig
    )

    XCTAssertEqual(config.aws.region, region)
    XCTAssertEqual(config.aws.rumAppMonitorId, rumAppMonitorId)
    XCTAssertEqual(config.aws.rumAlias, rumAlias)
    XCTAssertEqual(config.sessionTimeout, sessionTimeout)
    XCTAssertEqual(config.sessionSampleRate, sessionSampleRate)
    XCTAssertEqual(config.debug, true)
  }

  func testAwsOpenTelemetryConfigManualInitWithDefaults() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: rumAppMonitorId)
    let config = AwsOpenTelemetryConfig(aws: awsConfig)

    XCTAssertNil(config.exportOverride)
    XCTAssertNil(config.sessionTimeout)
    XCTAssertNil(config.sessionSampleRate)
    XCTAssertNil(config.debug)
    XCTAssertNotNil(config.telemetry)
    XCTAssertEqual(config.telemetry?.startup?.enabled, true)
    XCTAssertEqual(config.telemetry?.sessionEvents?.enabled, true)
    XCTAssertEqual(config.telemetry?.crash?.enabled, true)
    XCTAssertEqual(config.telemetry?.network?.enabled, true)
    XCTAssertEqual(config.telemetry?.hang?.enabled, true)
    XCTAssertEqual(config.telemetry?.view?.enabled, true)
  }

  func testAwsOpenTelemetryConfigJSONDecoderWithValues() throws {
    let jsonString = """
    {
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(rumAppMonitorId)",
        "rumAlias": "\(rumAlias)",

      },
      "exportOverride": {
        "logs": "\(logsEndpoint)",
        "traces": "\(tracesEndpoint)"
      },
      "sessionTimeout": \(sessionTimeout),
      "sessionSampleRate": \(sessionSampleRate),
      "otelResourceAttributes": {
        "service.version": "1.0.0"
      },
      "debug": true,
      "telemetry": {
        "startup": { "enabled": false },
        "view": { "enabled": true }
      }
    }
    """

    let config = try JSONDecoder().decode(AwsOpenTelemetryConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.aws.region, region)
    XCTAssertEqual(config.aws.rumAppMonitorId, rumAppMonitorId)
    XCTAssertEqual(config.debug, true)
    XCTAssertEqual(config.sessionTimeout, sessionTimeout)
    XCTAssertEqual(config.telemetry?.startup?.enabled, false)
    XCTAssertEqual(config.telemetry?.sessionEvents?.enabled, true)
    XCTAssertEqual(config.telemetry?.crash?.enabled, true)
    XCTAssertEqual(config.telemetry?.network?.enabled, true)
    XCTAssertEqual(config.telemetry?.hang?.enabled, true)
    XCTAssertEqual(config.telemetry?.view?.enabled, true)
  }

  func testAwsOpenTelemetryConfigJSONDecoderWithDefaults() throws {
    let jsonString = """
    {
      "aws": {
        "region": "\(region)",
        "rumAppMonitorId": "\(rumAppMonitorId)"
      }
    }
    """

    let config = try JSONDecoder().decode(AwsOpenTelemetryConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.aws.region, region)
    XCTAssertNil(config.exportOverride)
    XCTAssertNil(config.debug)
    XCTAssertNotNil(config.telemetry)
    XCTAssertEqual(config.telemetry?.startup?.enabled, true)
    XCTAssertEqual(config.telemetry?.sessionEvents?.enabled, true)
    XCTAssertEqual(config.telemetry?.crash?.enabled, true)
    XCTAssertEqual(config.telemetry?.network?.enabled, true)
    XCTAssertEqual(config.telemetry?.hang?.enabled, true)
    XCTAssertEqual(config.telemetry?.view?.enabled, true)
  }

  func testAwsOpenTelemetryConfigBuilder() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: rumAppMonitorId)
    let exportOverride = AwsExportOverride(logs: logsEndpoint)
    let attributes = ["key": "value"]

    let config = AwsOpenTelemetryConfig.builder()
      .with(aws: awsConfig)
      .with(exportOverride: exportOverride)
      .with(sessionTimeout: sessionTimeout)
      .with(debug: true)
      .with(otelResourceAttributes: attributes)
      .build()

    XCTAssertEqual(config.aws.region, region)
    XCTAssertEqual(config.exportOverride?.logs, logsEndpoint)
    XCTAssertEqual(config.sessionTimeout, sessionTimeout)
    XCTAssertEqual(config.debug, true)
    XCTAssertEqual(config.otelResourceAttributes?["key"], "value")
    XCTAssertEqual(config.telemetry?.startup?.enabled, true)
    XCTAssertEqual(config.telemetry?.sessionEvents?.enabled, true)
    XCTAssertEqual(config.telemetry?.crash?.enabled, true)
    XCTAssertEqual(config.telemetry?.network?.enabled, true)
    XCTAssertEqual(config.telemetry?.hang?.enabled, true)
    XCTAssertEqual(config.telemetry?.view?.enabled, true)
  }
}
