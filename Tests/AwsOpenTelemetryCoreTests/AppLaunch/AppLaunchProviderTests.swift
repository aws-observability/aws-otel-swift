import XCTest
@testable import AwsOpenTelemetryCore

#if canImport(UIKit) && !os(watchOS)
  import UIKit

  final class DefaultAppLaunchProviderUIKitTests: XCTestCase {
    func testColdLaunchStartTime() {
      let provider = DefaultAppLaunchProvider.shared

      XCTAssertNotNil(provider.coldLaunchStartTime, "Cold launch start time should not be nil")
      XCTAssertTrue(provider.coldLaunchStartTime! <= Date(), "Cold launch start time should be in the past")
    }

    func testGetProcessStartTimeErrorHandling() {
      let startTime = DefaultAppLaunchProvider.getProcessStartTime()
      XCTAssertNotNil(startTime)
    }

    func testColdStartName() {
      let provider = DefaultAppLaunchProvider.shared

      XCTAssertEqual(provider.coldStartName, "kp_proc.p_starttime")
    }

    func testNotificationNames() {
      let provider = DefaultAppLaunchProvider.shared
      XCTAssertEqual(provider.warmStartNotification, UIApplication.willEnterForegroundNotification)
      XCTAssertEqual(provider.launchEndNotification, UIApplication.didBecomeActiveNotification)
      XCTAssertEqual(provider.hiddenNotification, UIApplication.didEnterBackgroundNotification)
    }

    func testPreWarmFallbackThreshold() {
      let provider = DefaultAppLaunchProvider.shared
      XCTAssertEqual(provider.preWarmFallbackThreshold, 30.0)
    }

    func testAdditionalLifecycleEvents() {
      let provider = DefaultAppLaunchProvider.shared
      let expectedEvents: [Notification.Name] = [
        UIApplication.didFinishLaunchingNotification,
        UIApplication.didEnterBackgroundNotification,
        UIApplication.willResignActiveNotification,
        UIApplication.willTerminateNotification
      ]

      XCTAssertEqual(provider.additionalLifecycleEvents.count, expectedEvents.count)
      for event in expectedEvents {
        XCTAssertTrue(provider.additionalLifecycleEvents.contains(event))
      }
    }

    func testGetProcessStartTime() {
      let startTime = DefaultAppLaunchProvider.getProcessStartTime()

      XCTAssertNotNil(startTime, "Process start time should not be nil")
      XCTAssertTrue(startTime! <= Date(), "Process start time should be in the past")

      // Process should have started within reasonable time (e.g., last hour)
      let oneHourAgo = Date().addingTimeInterval(-3600)
      XCTAssertTrue(startTime! >= oneHourAgo, "Process start time should be recent")
    }

    func testProcessStartTimeConsistency() {
      let time1 = DefaultAppLaunchProvider.getProcessStartTime()
      let time2 = DefaultAppLaunchProvider.getProcessStartTime()

      XCTAssertNotNil(time1)
      XCTAssertNotNil(time2)

      // Should return the same time (within small tolerance for execution time)
      let timeDifference = abs(time1!.timeIntervalSince(time2!))
      XCTAssertLessThan(timeDifference, 0.001, "Process start time should be consistent")
    }

    func testSharedInstanceConsistency() {
      let provider1 = DefaultAppLaunchProvider.shared
      let provider2 = DefaultAppLaunchProvider.shared

      XCTAssertTrue(provider1 === provider2, "Shared instance should be the same object")
    }
  }

#else

  final class DefaultAppLaunchProviderNonUIKitTests: XCTestCase {
    func testNonUIKitPlatformBehavior() {
      let provider = DefaultAppLaunchProvider.shared

      // Process start time should still work on non-UIKit platforms
      XCTAssertNotNil(provider.coldLaunchStartTime, "Cold launch start time should not be nil")
      XCTAssertTrue(provider.coldLaunchStartTime! <= Date(), "Cold launch start time should be in the past")

      // Cold start name should be consistent
      XCTAssertEqual(provider.coldStartName, "kp_proc.p_starttime")

      // No-op notifications should be used
      XCTAssertEqual(provider.warmStartNotification, Notification.Name("noop.warm"))
      XCTAssertEqual(provider.launchEndNotification, Notification.Name("noop.end"))
      XCTAssertEqual(provider.hiddenNotification, Notification.Name("noop.hidden"))

      // No additional lifecycle events on non-UIKit platforms
      XCTAssertTrue(provider.additionalLifecycleEvents.isEmpty)

      // Threshold should still be set
      XCTAssertEqual(provider.preWarmFallbackThreshold, 30.0)
    }

    func testGetProcessStartTimeOnNonUIKitPlatforms() {
      let startTime = DefaultAppLaunchProvider.getProcessStartTime()

      XCTAssertNotNil(startTime, "Process start time should not be nil")
      XCTAssertTrue(startTime! <= Date(), "Process start time should be in the past")
    }

    func testSharedInstanceConsistency() {
      let provider1 = DefaultAppLaunchProvider.shared
      let provider2 = DefaultAppLaunchProvider.shared

      XCTAssertTrue(provider1 === provider2, "Shared instance should be the same object")
    }
  }

#endif
