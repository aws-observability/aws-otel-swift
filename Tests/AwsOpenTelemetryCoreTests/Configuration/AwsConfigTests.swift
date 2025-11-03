import XCTest
@testable import AwsOpenTelemetryCore

final class AwsConfigTests: XCTestCase {
  let region = "us-west-2"
  let rumAppMonitorId = "test-monitor-id"
  let rumAlias = "test-alias"
  let cognitoIdentityPool = "test-identity-pool"

  func testAwsConfigInitWithValues() {
    let config = AwsConfig(
      region: region,
      rumAppMonitorId: rumAppMonitorId,
      rumAlias: rumAlias,
      cognitoIdentityPool: cognitoIdentityPool
    )

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertEqual(config.rumAlias, rumAlias)
    XCTAssertEqual(config.cognitoIdentityPool, cognitoIdentityPool)
  }

  func testAwsConfigInitWithDefaults() {
    let config = AwsConfig(region: region, rumAppMonitorId: rumAppMonitorId)

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertNil(config.rumAlias)
    XCTAssertNil(config.cognitoIdentityPool)
  }

  func testAwsConfigJSONDecoderWithValues() throws {
    let jsonString = """
    {
      "region": "\(region)",
      "rumAppMonitorId": "\(rumAppMonitorId)",
      "rumAlias": "\(rumAlias)",
      "cognitoIdentityPool": "\(cognitoIdentityPool)"
    }
    """

    let config = try JSONDecoder().decode(AwsConfig.self, from: jsonString.data(using: .utf8)!)

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertEqual(config.rumAlias, rumAlias)
    XCTAssertEqual(config.cognitoIdentityPool, cognitoIdentityPool)
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
    XCTAssertNil(config.cognitoIdentityPool)
  }

  func testAwsConfigBuilder() {
    let config = AwsConfig.builder()
      .with(region: region)
      .with(rumAppMonitorId: rumAppMonitorId)
      .with(rumAlias: rumAlias)
      .with(cognitoIdentityPool: cognitoIdentityPool)
      .build()

    XCTAssertEqual(config.region, region)
    XCTAssertEqual(config.rumAppMonitorId, rumAppMonitorId)
    XCTAssertEqual(config.rumAlias, rumAlias)
    XCTAssertEqual(config.cognitoIdentityPool, cognitoIdentityPool)
  }
}
