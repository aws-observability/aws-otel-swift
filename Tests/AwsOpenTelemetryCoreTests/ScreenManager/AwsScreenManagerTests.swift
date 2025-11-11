import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk
@testable import TestUtils

final class AwsScreenManagerTests: XCTestCase {
  var screenManager: AwsScreenManager!
  var logExporter: InMemoryLogExporter!
  var logger: Logger!

  override func setUp() {
    super.setUp()
    screenManager = AwsScreenManager()
    logExporter = InMemoryLogExporter.register()
    logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: "test")
  }

  override func tearDown() {
    logExporter.clear()
    super.tearDown()
  }

  func testInitialState() {
    XCTAssertNil(screenManager.currentScreen)
    XCTAssertEqual(screenManager.interaction, 0)
    XCTAssertFalse(screenManager.viewDidAppear)
  }

  func testSetCurrentScreen() {
    screenManager.setCurrent(screen: "HomeScreen")
    XCTAssertEqual(screenManager.currentScreen, "HomeScreen")
    XCTAssertEqual(screenManager.interaction, 1)
    XCTAssertFalse(screenManager.viewDidAppear)
  }

  func testSetCurrentScreenSameTwice() {
    screenManager.setCurrent(screen: "HomeScreen")
    XCTAssertEqual(screenManager.interaction, 1)
    screenManager.setCurrent(screen: "HomeScreen")
    XCTAssertEqual(screenManager.currentScreen, "HomeScreen")
    XCTAssertEqual(screenManager.interaction, 1)
  }

  func testSetCurrentScreenDifferent() {
    screenManager.setCurrent(screen: "HomeScreen")
    XCTAssertEqual(screenManager.interaction, 1)
    screenManager.setCurrent(screen: "ProfileScreen")
    XCTAssertEqual(screenManager.currentScreen, "ProfileScreen")
    XCTAssertEqual(screenManager.interaction, 2)
    XCTAssertFalse(screenManager.viewDidAppear)
  }

  func testLogViewDidAppear() {
    screenManager.setCurrent(screen: "HomeScreen")

    screenManager.logViewDidAppear(
      screen: "HomeScreen",
      type: .swiftui,
      timestamp: Date(),
      logger: logger
    )

    let logs = logExporter.getExportedLogs()
    XCTAssertEqual(logs.count, 1)
    let logRecord = logs[0]
    XCTAssertEqual(logRecord.eventName, AwsViewDidAppearSemConv.name)
    XCTAssertEqual(logRecord.attributes[AwsViewDidAppearSemConv.screenName], AttributeValue.string("HomeScreen"))
    XCTAssertEqual(logRecord.attributes[AwsViewDidAppearSemConv.type], AttributeValue.string("swiftui"))
    XCTAssertEqual(logRecord.attributes[AwsViewDidAppearSemConv.interaction], AttributeValue.int(1))
  }

  func testLogViewDidAppearTwice() {
    screenManager.setCurrent(screen: "HomeScreen")
    XCTAssertFalse(screenManager.viewDidAppear)

    screenManager.logViewDidAppear(
      screen: "HomeScreen",
      type: .swiftui,
      timestamp: Date(),
      logger: logger
    )

    XCTAssertTrue(screenManager.viewDidAppear)
    XCTAssertEqual(logExporter.getExportedLogs().count, 1)

    screenManager.logViewDidAppear(
      screen: "HomeScreen",
      type: .swiftui,
      timestamp: Date(),
      logger: logger
    )

    XCTAssertEqual(logExporter.getExportedLogs().count, 1)
  }

  func testLogViewDidAppearScreenMismatch() {
    screenManager.setCurrent(screen: "HomeScreen")

    screenManager.logViewDidAppear(
      screen: "ProfileScreen",
      type: .swiftui,
      timestamp: Date(),
      logger: logger
    )

    XCTAssertEqual(logExporter.getExportedLogs().count, 0)
  }

  func testLogViewDidAppearWithAdditionalAttributes() {
    screenManager.setCurrent(screen: "HomeScreen")

    let additionalAttributes = [
      "custom.key": AttributeValue.string("custom.value"),
      "user.id": AttributeValue.int(123)
    ]

    screenManager.logViewDidAppear(
      screen: "HomeScreen",
      type: .uikit,
      timestamp: Date(),
      logger: logger,
      additionalAttributes: additionalAttributes
    )

    let logs = logExporter.getExportedLogs()
    XCTAssertEqual(logs.count, 1)
    let logRecord = logs[0]
    XCTAssertEqual(logRecord.attributes["custom.key"], AttributeValue.string("custom.value"))
    XCTAssertEqual(logRecord.attributes["user.id"], AttributeValue.int(123))
  }

  func testInteractionIncrement() {
    screenManager.setCurrent(screen: "HomeScreen")
    XCTAssertEqual(screenManager.interaction, 1)
    screenManager.logViewDidAppear(screen: "HomeScreen", type: .swiftui, timestamp: Date(), logger: logger)

    screenManager.setCurrent(screen: "ProfileScreen")
    XCTAssertEqual(screenManager.interaction, 2)
    XCTAssertFalse(screenManager.viewDidAppear)
    screenManager.logViewDidAppear(screen: "ProfileScreen", type: .swiftui, timestamp: Date(), logger: logger)

    let logs = logExporter.getExportedLogs()
    XCTAssertEqual(logs.count, 2)
    XCTAssertEqual(logs[0].attributes[AwsViewDidAppearSemConv.interaction], AttributeValue.int(1))
    XCTAssertEqual(logs[1].attributes[AwsViewDidAppearSemConv.interaction], AttributeValue.int(2))
  }

  func testSetCurrentPostsNotification() {
    let expectation = XCTestExpectation(description: "Screen change notification")
    var receivedScreenName: String?

    let observer = NotificationCenter.default.addObserver(
      forName: AwsScreenChangeNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedScreenName = notification.object as? String
      expectation.fulfill()
    }

    screenManager.setCurrent(screen: "TestScreen")

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedScreenName, "TestScreen")

    NotificationCenter.default.removeObserver(observer)
  }

  func testMultipleScreenChangesPostMultipleNotifications() {
    var receivedScreens: [String] = []
    let expectation = XCTestExpectation(description: "Multiple screen notifications")
    expectation.expectedFulfillmentCount = 3

    let observer = NotificationCenter.default.addObserver(
      forName: AwsScreenChangeNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let screen = notification.object as? String {
        receivedScreens.append(screen)
      }
      expectation.fulfill()
    }

    screenManager.setCurrent(screen: "Screen1")
    screenManager.setCurrent(screen: "Screen2")
    screenManager.setCurrent(screen: "Screen3")

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedScreens, ["Screen1", "Screen2", "Screen3"])

    NotificationCenter.default.removeObserver(observer)
  }
}
