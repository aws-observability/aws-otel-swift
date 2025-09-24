import XCTest

final class PerformanceTests: XCTestCase {
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  @MainActor
  func testLaunchPerformance() throws {
    // This measures how long it takes to launch your application.
    measure(metrics: [XCTApplicationLaunchMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
      XCUIApplication().launch()
    }
  }

  // @MainActor
  // func testNetworkRequestPerformance() throws {
  //     // This measures how long it takes to launch your application.
  //     let app = XCUIApplication()
  //     app.launch()

  //     let scrollView: XCUIElement = app.scrollViews["SampleScrollView"]
  //     let http5xxRequestButton: XCUIElement = app.buttons["5xx HTTP Request"]
  //     var scrollCount = 0
  //     let maxScrollAttempts = 10
  //     while !http5xxRequestButton.isHittable, scrollCount < maxScrollAttempts {
  //         scrollView.swipeUp(velocity: XCUIGestureVelocity(100))
  //         scrollCount += 1
  //     }

  //     measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
  //         http5xxRequestButton.tap()
  //     }
  // }
}
