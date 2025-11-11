import XCTest
@testable import AwsOpenTelemetryCore

final class AwsScreenManagerProviderTests: XCTestCase {
  func testGetInstanceReturnsSameInstance() {
    let instance1 = AwsScreenManagerProvider.getInstance()
    let instance2 = AwsScreenManagerProvider.getInstance()

    XCTAssertTrue(instance1 === instance2)
  }

  func testGetInstanceReturnsScreenManager() {
    let instance = AwsScreenManagerProvider.getInstance()
    XCTAssertNotNil(instance)
  }
}
