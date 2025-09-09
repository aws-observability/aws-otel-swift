import XCTest

class UITestsSwiftUITests: XCTestCase {
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
  func testUIKitActions() throws {
    let scrollView: XCUIElement = app.scrollViews["SampleScrollView"]
    let uiKitDemoButton: XCUIElement = app.buttons["Show UIKit Demo"]
    var scrollCount = 0
    let maxScrollAttempts = 10
    while !uiKitDemoButton.isHittable, scrollCount < maxScrollAttempts {
      scrollView.swipeUp(velocity: XCUIGestureVelocity(100))
      scrollCount += 1
    }
    uiKitDemoButton.tap()
    app.buttons["Perform Action"].tap()
    app.alerts["Action Performed"].buttons["OK"].tap()
    app.buttons["Close"].tap()
  }
}
