import XCTest

final class UITestsMetricKitTests: XCTestCase {
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
  func testAppHang() throws {
    let scrollView: XCUIElement = app.scrollViews["SampleScrollView"]
    let simulateAnrButton: XCUIElement = app.buttons["Simulate ANR (2 sec)"]
    var scrollCount = 0
    let maxScrollAttempts = 10
    while !simulateAnrButton.isHittable, scrollCount < maxScrollAttempts {
      scrollView.swipeUp(velocity: XCUIGestureVelocity(100))
      scrollCount += 1
    }
    simulateAnrButton.tap()
    sleep(5)
  }
}
