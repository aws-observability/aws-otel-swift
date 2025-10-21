import XCTest

/**
 * Comprehensive instrumented test that generates telemetry by interacting with all UI elements.
 * This test navigates through all screens, clicks buttons, performs searches, and interacts
 * with various UI components to generate comprehensive telemetry data.
 *
 * The ANR and Crash buttons are saved for last as they will terminate the test.
 */
class SimplePetClinicUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  @MainActor
  func testGenerateComprehensiveTelemetry() throws {
    let app = XCUIApplication()
    app.launch()

    // Wait for app to load
    sleep(2)

    navigateToOwnersScreen(app: app)
    navigateToVetsScreen(app: app)
    navigateToHomeScreen(app: app)
    testUIJankFeature(app: app)
    performFinalNavigationRound(app: app)
    performDestructiveTests(app: app)

    // Wait for telemetry to be sent
    sleep(30)
  }

  @MainActor
  func testGenerateCrashTelemetry() throws {
    let app = XCUIApplication()
    app.launch()

    sleep(2)

    // Scroll down to find testing section
    app.scrollViews.firstMatch.swipeUp()
    app.scrollViews.firstMatch.swipeUp()

    app.buttons["💥 Trigger App Crash"].tap()

    // App will crash here

    // Launch app again to capture telemetry
    app.launch()

    sleep(2)
  }

  private func navigateToOwnersScreen(app: XCUIApplication) {
    app.tabBars.buttons["Owners"].tap()
    sleep(2)
  }

  private func navigateToVetsScreen(app: XCUIApplication) {
    app.tabBars.buttons["Vets"].tap()
    sleep(2)
  }

  private func navigateToHomeScreen(app: XCUIApplication) {
    app.tabBars.buttons["Home"].tap()
    sleep(2)
  }

  private func testUIJankFeature(app: XCUIApplication) {
    // Scroll down to find testing section
    app.scrollViews.firstMatch.swipeUp()
    app.scrollViews.firstMatch.swipeUp()

    // Start UI Jank
    app.buttons["🟡 Start UI Jank"].tap()
    sleep(5) // Let jank run

    // Stop UI Jank
    app.buttons["🟢 Stop UI Jank"].tap()
    sleep(1)
  }

  private func performFinalNavigationRound(app: XCUIApplication) {
    // Another round of navigation for more telemetry
    app.tabBars.buttons["Owners"].tap()
    sleep(2)

    app.tabBars.buttons["Vets"].tap()
    sleep(2)

    app.tabBars.buttons["Home"].tap()
    sleep(1)
  }

  private func performDestructiveTests(app: XCUIApplication) {
    // Scroll down to find testing section
    app.scrollViews.firstMatch.swipeUp()
    app.scrollViews.firstMatch.swipeUp()

    // Test API call
    app.buttons["🌐 Test API Call"].tap()
    sleep(2)

    // Test network error 404
    app.buttons["🚫 Simulate Network Error 404"].tap()
    sleep(2)

    // Test network error 500
    app.buttons["🚫 Simulate Network Error 500"].tap()
    sleep(2)

    // Test ANR (blocks for 10s)
    app.buttons["⏰ Trigger ANR (10s block)"].tap()
    sleep(15) // Wait longer than ANR timeout
  }

  @MainActor
  func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }
}
