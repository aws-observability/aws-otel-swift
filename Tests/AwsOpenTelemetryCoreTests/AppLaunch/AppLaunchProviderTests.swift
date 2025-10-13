import XCTest
@testable import AwsOpenTelemetryCore

#if canImport(UIKit) && !os(watchOS)
  import UIKit
#endif

final class AppLaunchProviderTests: XCTestCase {
  func testDefaultAppLaunchProviderSharedInstance() {
    let provider1 = DefaultAppLaunchProvider.shared
    let provider2 = DefaultAppLaunchProvider.shared

    XCTAssertTrue(provider1 === provider2, "Shared instance should be singleton")
  }

  func testColdLaunchStartTimeIsReasonable() {
    let provider = DefaultAppLaunchProvider.shared
    let now = Date()

    XCTAssertLessThanOrEqual(provider.coldLaunchStartTime, now, "Start time should be before or equal to current time")
    XCTAssertGreaterThan(now.timeIntervalSince(provider.coldLaunchStartTime), 0, "Start time should be in the past")
    XCTAssertLessThan(now.timeIntervalSince(provider.coldLaunchStartTime), 60, "Start time should be recent (within 60 seconds)")
  }

  func testPreWarmFallbackThreshold() {
    let provider = DefaultAppLaunchProvider.shared
    XCTAssertEqual(provider.preWarmFallbackThreshold, 30.0, "Pre-warm threshold should be 30 seconds")
  }

  #if canImport(UIKit) && !os(watchOS)
    func testNotificationNames() {
      let provider = DefaultAppLaunchProvider.shared

      XCTAssertEqual(provider.coldLaunchEndNotification, UIApplication.didFinishLaunchingNotification)
      XCTAssertEqual(provider.warmLaunchStartNotification, UIApplication.willEnterForegroundNotification)
      XCTAssertEqual(provider.warmLaunchEndNotification, UIApplication.didBecomeActiveNotification)
    }
  #endif

  func testAppLaunchProviderProtocolConformance() {
    let provider: AppLaunchProvider = DefaultAppLaunchProvider.shared

    XCTAssertGreaterThanOrEqual(provider.coldLaunchStartTime.timeIntervalSince1970, 0)
    XCTAssertNotNil(provider.coldLaunchEndNotification)
    XCTAssertNotNil(provider.warmLaunchStartNotification)
    XCTAssertNotNil(provider.warmLaunchEndNotification)
    XCTAssertGreaterThanOrEqual(provider.preWarmFallbackThreshold, 0)
  }
}
