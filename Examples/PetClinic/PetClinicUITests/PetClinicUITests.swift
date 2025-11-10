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
  // Detect Device Farm environment and use shorter durations
  private var isDeviceFarm: Bool {
    ProcessInfo.processInfo.environment["DEVICEFARM_DEVICE_UDID"] != nil
  }

  private var sleepIntervalSeconds: TimeInterval {
    isDeviceFarm ? 2 * 60 : 27 * 60 // 2 minutes for Device Farm, 27 for local
  }

  private var timeoutSeconds: TimeInterval {
    isDeviceFarm ? 5 * 60 : 30 * 60 // 5 minutes for Device Farm, 30 for local
  }

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
    app.launch()

    let numberOfIntervals = isDeviceFarm ? 2 : 4 // Fewer intervals for Device Farm

    // Loop for the entire test session
    for i in 0 ..< numberOfIntervals {
      print("Generating telemetry for interval \(i + 1)...")
      generateAllTelemetry(app: app)

      if i < numberOfIntervals - 1 { // Don't idle after last interval
        let idleDuration = isDeviceFarm ? 2 : 28 // 2 minutes for Device Farm
        print("Idling for \(idleDuration) minutes...")
        idleForDuration(app: app, minutes: idleDuration)
      }
    }
  }

  @MainActor
  func testGenerateCrashTelemetry() throws {
    let app = XCUIApplication()
    // Fetch parameters from local server

    app.launch()

    // Scroll down to find testing section
    app.scrollViews.firstMatch.swipeUp()
    app.scrollViews.firstMatch.swipeUp()

    app.buttons["💥 Trigger App Crash"].tap()

    // App will crash here

    // Launch app again to capture telemetry
    app.launch()
    Thread.sleep(forTimeInterval: 2.0)
  }

  private func idleForDuration(app: XCUIApplication, minutes: Int) {
    let startTime = Date()
    let duration = TimeInterval(minutes * 60)
    let navigationInterval: TimeInterval = isDeviceFarm ? 15 : 30 // More frequent checks on Device Farm

    // Perform periodic navigation while waiting
    while Date().timeIntervalSince(startTime) < duration {
      // Check if app is still responsive before navigation
      if app.state == .runningForeground {
        navigateToOwnersScreen(app: app)
        navigateToVetsScreen(app: app)
      } else {
        print("App not in foreground, skipping navigation")
        break
      }
      Thread.sleep(forTimeInterval: navigationInterval)
    }
  }

  private func generateAllTelemetry(app: XCUIApplication) {
    navigateToOwnersScreen(app: app)
    navigateToVetsScreen(app: app)
    navigateToHomeScreen(app: app)
    testUIJankFeature(app: app)
    performFinalNavigationRound(app: app)
    performDestructiveTests(app: app)

    // Wait for telemetry to be sent
    Thread.sleep(forTimeInterval: 5.0)
  }

  private func navigateToOwnersScreen(app: XCUIApplication) {
    let ownersButton = app.tabBars.buttons["Owners"]
    if ownersButton.waitForExistence(timeout: 5), ownersButton.isHittable {
      ownersButton.tap()
    } else {
      print("Owners button not found or not hittable")
    }
  }

  private func navigateToVetsScreen(app: XCUIApplication) {
    let vetsButton = app.tabBars.buttons["Vets"]
    if vetsButton.waitForExistence(timeout: 5), vetsButton.isHittable {
      vetsButton.tap()
    } else {
      print("Vets button not found or not hittable")
    }
  }

  private func navigateToHomeScreen(app: XCUIApplication) {
    let homeButton = app.tabBars.buttons["Home"]
    if homeButton.waitForExistence(timeout: 5), homeButton.isHittable {
      homeButton.tap()
    } else {
      print("Home button not found or not hittable")
    }
  }

  private func testUIJankFeature(app: XCUIApplication) {
    // Scroll down to find testing section
    app.scrollViews.firstMatch.swipeUp()
    app.scrollViews.firstMatch.swipeUp()

    // Start UI Jank
    let uiJankStartButton = app.buttons["🟡 Start UI Jank"]
    if uiJankStartButton.waitForExistence(timeout: 5), uiJankStartButton.isHittable {
      uiJankStartButton.tap()
    }

    // Stop UI Jank
    let uiJankStopButton = app.buttons["🟢 Stop UI Jank"]
    if uiJankStopButton.waitForExistence(timeout: 5), uiJankStopButton.isHittable {
      uiJankStopButton.tap()
    }
  }

  private func performFinalNavigationRound(app: XCUIApplication) {
    // Another round of navigation for more telemetry
    navigateToOwnersScreen(app: app)
    navigateToVetsScreen(app: app)
    navigateToHomeScreen(app: app)
  }

  private func performDestructiveTests(app: XCUIApplication) {
    // Scroll down to find testing section
    app.scrollViews.firstMatch.swipeUp()
    app.scrollViews.firstMatch.swipeUp()

    // Test API call
    let testApiCallButton = app.buttons["🌐 Test API Call"]
    if testApiCallButton.waitForExistence(timeout: 5), testApiCallButton.isHittable {
      testApiCallButton.tap()
    }

    // Test network error 404
    let networkError404Button = app.buttons["🚫 Simulate Network Error 404"]
    if networkError404Button.waitForExistence(timeout: 5), networkError404Button.isHittable {
      networkError404Button.tap()
      let okButton = app.alerts["Error"].firstMatch.buttons["OK"]
      if okButton.waitForExistence(timeout: 5), okButton.isHittable {
        okButton.tap()
      }
    }

    // Test network error 500
    let networkError500Button = app.buttons["🚫 Simulate Network Error 500"]
    if networkError500Button.waitForExistence(timeout: 5), networkError500Button.isHittable {
      networkError500Button.tap()
      let okButton = app.alerts["Error"].firstMatch.buttons["OK"]
      if okButton.waitForExistence(timeout: 5), okButton.isHittable {
        okButton.tap()
      }
    }

    // Test ANR (blocks for 10s)
    let anrButton = app.buttons["⏰ Trigger ANR (10s block)"]
    if anrButton.waitForExistence(timeout: 5), anrButton.isHittable {
      anrButton.tap()
    }
  }
}
