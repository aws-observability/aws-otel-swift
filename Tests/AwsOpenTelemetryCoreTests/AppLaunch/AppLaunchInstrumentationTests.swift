import XCTest
@testable import AwsOpenTelemetryCore
@testable import TestUtils
import OpenTelemetryApi

#if canImport(UIKit) && !os(watchOS)
  import UIKit
#endif

final class AppLaunchInstrumentationTests: XCTestCase {
  var spanExporter: InMemorySpanExporter!
  var mockProvider: MockAppLaunchProvider!

  override func setUp() {
    super.setUp()
    spanExporter = InMemorySpanExporter.register()
    mockProvider = MockAppLaunchProvider()
    resetAppLaunchInstrumentationState()
  }

  override func tearDown() {
    spanExporter.reset()
    resetAppLaunchInstrumentationState()
    super.tearDown()
  }

  private func resetAppLaunchInstrumentationState() {
    AppLaunchInstrumentation.lock.lock()
    defer { AppLaunchInstrumentation.lock.unlock() }
    AppLaunchInstrumentation.initialLaunchRecorded = false
    AppLaunchInstrumentation.warmLaunchStartTime = nil
  }

  func testInstrumentationKey() {
    XCTAssertEqual(AppLaunchInstrumentation.instrumentationKey, AwsInstrumentationScopes.APP_START)
  }

  func testColdLaunchSpanCreation() {
    let _ = AppLaunchInstrumentation(provider: MockAppLaunchProvider(coldLaunchStartTime: Date()))

    NotificationCenter.default.post(name: mockProvider.coldLaunchEndNotification, object: nil)

    // Wait for notification to be processed
    let expectation = XCTestExpectation(description: "Span created")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    let spans = spanExporter.getExportedSpans()
    XCTAssertEqual(spans.count, 1)

    let span = spans[0]
    XCTAssertEqual(span.name, "AppStart")
    XCTAssertEqual(span.attributes["launch.type"]?.description, "COLD")
    XCTAssertEqual(span.attributes["app.launch.end_notification"]?.description, mockProvider.coldLaunchEndNotification.rawValue)
    XCTAssertEqual(span.attributes["active_prewarm"]?.description, "false")
  }

  func testPrewarmLaunchDetection() {
    let longThresholdProvider = MockAppLaunchProvider(
      coldLaunchStartTime: Date(timeIntervalSinceNow: -40),
      preWarmFallbackThreshold: 30.0
    )
    let _ = AppLaunchInstrumentation(provider: longThresholdProvider)

    NotificationCenter.default.post(name: longThresholdProvider.coldLaunchEndNotification, object: nil)

    // Wait for notification to be processed
    let expectation = XCTestExpectation(description: "Span created")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    let spans = spanExporter.getExportedSpans()
    XCTAssertEqual(spans.count, 1)
    XCTAssertEqual(spans[0].attributes["launch.type"]?.description, "PRE_WARM")
  }

  func testWarmLaunchSpanCreation() {
    let _ = AppLaunchInstrumentation(provider: mockProvider)

    // Set initial launch as recorded and set warm start time
    AppLaunchInstrumentation.initialLaunchRecorded = true
    AppLaunchInstrumentation.warmLaunchStartTime = Date()

    // Trigger warm launch end
    NotificationCenter.default.post(name: mockProvider.warmLaunchEndNotification, object: nil)

    // Wait for notification to be processed
    let expectation = XCTestExpectation(description: "Span created")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    let spans = spanExporter.getExportedSpans()
    XCTAssertEqual(spans.count, 1)

    let span = spans[0]
    XCTAssertEqual(span.name, "AppStart")
    XCTAssertEqual(span.attributes["launch.type"]?.description, "WARM")
    XCTAssertEqual(span.attributes["app.launch.start_notification"]?.description, mockProvider.warmLaunchStartNotification.rawValue)
    XCTAssertEqual(span.attributes["app.launch.end_notification"]?.description, mockProvider.warmLaunchEndNotification.rawValue)
  }

  func testWarmLaunchSkippedBeforeColdLaunch() {
    let _ = AppLaunchInstrumentation(provider: mockProvider)

    // Trigger warm launch without cold launch first
    NotificationCenter.default.post(name: mockProvider.warmLaunchStartNotification, object: nil)
    NotificationCenter.default.post(name: mockProvider.warmLaunchEndNotification, object: nil)

    // Wait for notifications to be processed
    let expectation = XCTestExpectation(description: "Notifications processed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    let spans = spanExporter.getExportedSpans()
    XCTAssertEqual(spans.count, 0, "Warm launch should be skipped before cold launch is recorded")
  }

  func testHasActivePrewarmEnvironmentVariable() {
    let instrumentation = AppLaunchInstrumentation(provider: mockProvider)

    // Test without environment variable
    XCTAssertFalse(instrumentation.hasActivePrewarm)
  }

  func testIsPrewarmLaunchLogic() {
    let instrumentation = AppLaunchInstrumentation(provider: mockProvider)

    // Test duration below threshold
    XCTAssertFalse(instrumentation.isPrewarmLaunch(duration: 10.0))

    // Test duration above threshold
    XCTAssertTrue(instrumentation.isPrewarmLaunch(duration: 40.0))

    // Test with zero threshold
    let zeroProvider = MockAppLaunchProvider(preWarmFallbackThreshold: 0.0)
    let zeroInstrumentation = AppLaunchInstrumentation(provider: zeroProvider)
    XCTAssertFalse(zeroInstrumentation.isPrewarmLaunch(duration: 40.0))
  }

  func testWarmLaunchPrewarmDetection() {
    let _ = AppLaunchInstrumentation(provider: mockProvider)

    // Set up initial launch
    NotificationCenter.default.post(name: mockProvider.coldLaunchEndNotification, object: nil)

    // Wait for initial launch to be processed
    let initialExpectation = XCTestExpectation(description: "Initial launch processed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      initialExpectation.fulfill()
    }
    wait(for: [initialExpectation], timeout: 1.0)

    spanExporter.reset()

    // Manually set a start time that would trigger prewarm before warm launch
    AppLaunchInstrumentation.warmLaunchStartTime = Date(timeIntervalSinceNow: -40)

    NotificationCenter.default.post(name: mockProvider.warmLaunchEndNotification, object: nil)

    // Wait for warm launch to be processed
    let warmExpectation = XCTestExpectation(description: "Warm launch processed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      warmExpectation.fulfill()
    }
    wait(for: [warmExpectation], timeout: 1.0)

    let spans = spanExporter.getExportedSpans()
    XCTAssertEqual(spans.count, 1)
    XCTAssertEqual(spans[0].attributes["launch.type"]?.description, "PRE_WARM")
  }

  func testStaticStateManagement() {
    XCTAssertFalse(AppLaunchInstrumentation.initialLaunchRecorded)
    XCTAssertNil(AppLaunchInstrumentation.warmLaunchStartTime)

    let _ = AppLaunchInstrumentation(provider: mockProvider)
    NotificationCenter.default.post(name: mockProvider.coldLaunchEndNotification, object: nil)

    // Wait for cold launch to be processed
    let coldExpectation = XCTestExpectation(description: "Cold launch processed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      coldExpectation.fulfill()
    }
    wait(for: [coldExpectation], timeout: 1.0)

    XCTAssertTrue(AppLaunchInstrumentation.initialLaunchRecorded)

    NotificationCenter.default.post(name: mockProvider.warmLaunchStartNotification, object: nil)

    // Wait for warm launch start to be processed
    let warmExpectation = XCTestExpectation(description: "Warm launch start processed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      warmExpectation.fulfill()
    }
    wait(for: [warmExpectation], timeout: 1.0)

    XCTAssertNotNil(AppLaunchInstrumentation.warmLaunchStartTime)
  }
}
