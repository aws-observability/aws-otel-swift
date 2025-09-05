import XCTest

final class UITestsLaunchTests: XCTestCase {
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
  func testLaunch() throws {
    let scrollView: XCUIElement = app.scrollViews["SampleScrollView"]
    let peekSessionButton: XCUIElement = app.buttons["Peek session"]
    var scrollCount = 0
    let maxScrollAttempts = 10
    while !peekSessionButton.isHittable, scrollCount < maxScrollAttempts {
      scrollView.swipeUp(velocity: XCUIGestureVelocity(100))
      scrollCount += 1
    }
    peekSessionButton.tap()
  }
}
