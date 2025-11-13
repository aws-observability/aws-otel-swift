import XCTest
@testable import AwsOpenTelemetryCore

final class AwsConfigTests: XCTestCase {
  let region = "us-west-2"
  let rumAppMonitorId = "test-monitor-id"
  let rumAlias = "test-alias"

  func testAwsConfigInitWithValues() {
    let config = AwsConfig(
      region: region,
      rumAppMonitorId: rumAppMonitorId,
      rumAlias: rumAlias
    )

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertEqual(config.rumAlias, rumAlias)
  }

  func testAwsConfigInitWithDefaults() {
    let config = AwsConfig(region: region, rumAppMonitorId: rumAppMonitorId)

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertNil(config.rumAlias)
  }

  func testAwsConfigJSONDecoderWithValues() throws {
    let jsonString = """
    {
      "region": "\(region)",
      "rumAppMonitorId": "\(rumAppMonitorId)",
      "rumAlias": "\(rumAlias)"
    }
    """

    let config = try JSONDecoder().decode(AwsConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertEqual(config.rumAlias, rumAlias)
  }

  func testAwsConfigJSONDecoderWithDefaults() throws {
    let jsonString = """
    {
      "region": "\(region)",
      "rumAppMonitorId": "\(rumAppMonitorId)"
    }
    """

    let config = try JSONDecoder().decode(AwsConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertNil(config.rumAlias)
  }

  func testAwsConfigBuilder() {
    let config = AwsConfig.builder()
      .with(region: region)
      .with(rumAppMonitorId: rumAppMonitorId)
      .with(rumAlias: rumAlias)
      .build()

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertEqual(config.rumAlias, rumAlias)
  }
}
