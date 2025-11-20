import XCTest
@testable import AwsOpenTelemetryCore

class AppStartTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // Verifies that app launch notification is logged when app starts
  func testAppLaunchLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let appStartLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.appstart" }
    let launchLog = appStartLogs.flatMap(\.logRecords).first { $0.eventName == "UIApplicationDidFinishLaunchingNotification" }

    XCTAssertNotNil(launchLog, "App launch log should exist")
  }

  // Verifies cold app start span with correct launch timing attributes
  func testAppStartSpanExists() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let appStartSpans = spans.filter { $0.scope.name == "software.amazon.opentelemetry.appstart" }
    let appStartSpan = appStartSpans.flatMap(\.spans).first { $0.name == "AppStart" }

    XCTAssertNotNil(appStartSpan, "AppStart span should exist")
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "start.type" }?.value.stringValue, "cold")
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "screen.name" }?.value.stringValue, "ContentView")
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "active_prewarm" }?.value.boolValue, false)
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "launch_end_name" }?.value.stringValue, "UIApplicationDidBecomeActiveNotification")
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "launch_start_name" }?.value.stringValue, "kp_proc.p_starttime")
  }

  // Verifies warm app start span when app returns from background
  func testWarmLaunchSpanExists() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let appStartSpans = spans.filter { $0.scope.name == "software.amazon.opentelemetry.appstart" }
    let warmLaunchSpan = appStartSpans.flatMap(\.spans).first { $0.attributes.contains { $0.key == "start.type" && $0.value.stringValue == "warm" } }

    XCTAssertNotNil(warmLaunchSpan, "Warm launch span should exist")
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "start.type" }?.value.stringValue, "warm")
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "screen.name" }?.value.stringValue, "ContentView")
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "active_prewarm" }?.value.boolValue, false)
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "launch_end_name" }?.value.stringValue, "UIApplicationDidBecomeActiveNotification")
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "launch_start_name" }?.value.stringValue, "UIApplicationWillEnterForegroundNotification")
  }
}
