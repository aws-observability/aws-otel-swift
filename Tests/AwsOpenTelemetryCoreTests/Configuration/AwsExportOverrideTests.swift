import XCTest
@testable import AwsOpenTelemetryCore

final class ExportOverrideTests: XCTestCase {
  let logsEndpoint = "https://custom-logs.example.com"
  let tracesEndpoint = "https://custom-traces.example.com"

  func testExportOverrideInitWithValues() {
    let overrides = AwsExportOverride(logs: logsEndpoint, traces: tracesEndpoint)

    XCTAssertEqual(overrides.logs, logsEndpoint)
    XCTAssertEqual(overrides.traces, tracesEndpoint)
  }

  func testExportOverrideInitWithDefaults() {
    let overrides = AwsExportOverride()

    XCTAssertNil(overrides.logs)
    XCTAssertNil(overrides.traces)
  }

  func testExportOverrideBuilder() {
    let config = AwsExportOverride.builder()
      .with(logs: logsEndpoint)
      .with(traces: tracesEndpoint)
      .build()

    XCTAssertEqual(config.logs, logsEndpoint)
    XCTAssertEqual(config.traces, tracesEndpoint)
  }
}
