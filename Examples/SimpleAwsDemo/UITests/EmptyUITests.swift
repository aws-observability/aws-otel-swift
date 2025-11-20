import XCTest

class EmptyUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments.append("--contractTestMode")
    app.launch()
  }

  func testLaunchApp() throws {
    print("Waiting 30 seconds for telemetry generation...")
    Thread.sleep(forTimeInterval: 30)
    print("Test completed")
    XCTAssertTrue(true)
  }
}
