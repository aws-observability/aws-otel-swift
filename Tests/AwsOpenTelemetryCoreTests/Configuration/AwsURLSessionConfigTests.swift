import XCTest
@testable import AwsOpenTelemetryCore

final class AwsURLSessionConfigTests: XCTestCase {
  let region = "us-west-2"
  let logsEndpoint = "https://custom-logs.example.com"
  let tracesEndpoint = "https://custom-traces.example.com"

  func testAwsURLSessionConfigInit() {
    let config = AwsURLSessionConfig(region: region)

    XCTAssertEqual(config.region, region)
    XCTAssertNil(config.exportOverride)
  }

  func testAwsURLSessionConfigInitWithExportOverride() {
    let exportOverride = AwsExportOverride(logs: logsEndpoint, traces: tracesEndpoint)
    let config = AwsURLSessionConfig(region: region, exportOverride: exportOverride)

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.exportOverride?.logs, logsEndpoint)
    XCTAssertEqual(config.exportOverride?.traces, tracesEndpoint)
  }

  func testAwsURLSessionConfigBuilder() {
    let exportOverride = AwsExportOverride(logs: logsEndpoint)
    let config = AwsURLSessionConfig.builder()
      .with(region: region)
      .with(exportOverride: exportOverride)
      .build()

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.exportOverride?.logs, logsEndpoint)
  }
}
