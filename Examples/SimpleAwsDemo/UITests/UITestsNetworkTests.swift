import XCTest

class UITestsNetworkTests: XCTestCase {
  var app: XCUIApplication!

  override class var runsForEachTargetApplicationUIConfiguration: Bool {
    true
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments.append("--contractTestMode")
    app.launch()
  }

  @MainActor
  func testNetworkGET200() throws {
    app.buttons["List S3 Buckets"].tap()
  }

  @MainActor
  func testNetworkGET404() throws {
    let scrollView: XCUIElement = app.scrollViews["SampleScrollView"]
    let http4xxRequestButton: XCUIElement = app.buttons["4xx HTTP Request"]
    var scrollCount = 0
    let maxScrollAttempts = 10
    while !http4xxRequestButton.isHittable, scrollCount < maxScrollAttempts {
      scrollView.swipeUp(velocity: XCUIGestureVelocity(100))
      scrollCount += 1
    }
    http4xxRequestButton.tap()
  }

  @MainActor
  func testNetworkGET500() throws {
    let scrollView: XCUIElement = app.scrollViews["SampleScrollView"]
    let http5xxRequestButton: XCUIElement = app.buttons["5xx HTTP Request"]
    var scrollCount = 0
    let maxScrollAttempts = 10
    while !http5xxRequestButton.isHittable, scrollCount < maxScrollAttempts {
      scrollView.swipeUp(velocity: XCUIGestureVelocity(100))
      scrollCount += 1
    }
    http5xxRequestButton.tap()
  }
}
