import XCTest
import Foundation

/**
 * Comprehensive instrumented test that generates telemetry by interacting with all UI elements.
 * This test navigates through all screens, clicks buttons, performs searches, and interacts
 * with various UI components to generate comprehensive telemetry data.
 *
 * The ANR and Crash buttons are saved for last as they will terminate the test.
 */
final class PetClinicUITests: XCTestCase {
  private let sleepIntervalSeconds: TimeInterval = 27 * 60 // 25 minutes
  private let timeoutSeconds: TimeInterval = 30 * 60 // 30 minutes

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  override class var runsForEachTargetApplicationUIConfiguration: Bool {
    false
  }

  @MainActor
  func testGenerateComprehensiveTelemetry() throws {
    let app = XCUIApplication()
    // Launch arguments are now injected via .xctestrun modification
    // They will automatically be available in UserDefaults
    app.launch()

    let numberOfIntervals = 4 // 4 times in 120 mins => once every 30 mins

    // Loop for the entire test session
    for i in 0 ..< numberOfIntervals {
      print("Generating telemetry for interval \(i + 1)...")
      generateAllTelemetry(app: app)

      print("Idling for 28 minutes...")
      idleFor28Minutes(app: app)
    }
  }

  @MainActor
  func testGenerateCrashTelemetry() throws {
    let app = XCUIApplication()
    // Fetch parameters from local server

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

  private func idleFor28Minutes(app: XCUIApplication) {
    let startTime = Date()
    let duration: TimeInterval = 28 * 60 // 28 minutes

    // Perform periodic navigation while waiting
    while Date().timeIntervalSince(startTime) < duration {
      navigateToOwnersScreen(app: app)
      navigateToVetsScreen(app: app)
      sleep(30) // Wait 30 seconds between navigation cycles
    }
  }

  private func generateAllTelemetry(app: XCUIApplication) {
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
    sleep(3)

    // Test network error 500
    app.buttons["🚫 Simulate Network Error 500"].tap()
    sleep(3)

    sleep(2)

    // Test ANR (blocks for 10s)
    app.buttons["⏰ Trigger ANR (10s block)"].tap()
    sleep(15) // Wait longer than ANR timeout
  }
}
