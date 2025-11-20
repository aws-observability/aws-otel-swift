import XCTest

class EmptyUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments.append("--contractTestMode")
    app.launch()
  }

  // Note: the 30 second stall is just to give the github host enough time to do all the mock interactions, and send all the telemtries
  // to the local endpoint. You can reduce this timeout significantly during local development (e.g. 15 seconds is more than enough).
  func testLaunchApp() throws {
    print("Waiting 15 seconds for telemetry generation...")
    Thread.sleep(forTimeInterval: 15)
    print("Test completed")
    XCTAssertTrue(true)
  }
}
