import XCTest
@testable import AwsOpenTelemetryCore

class SwiftUITests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // Verifies SwiftUI view appearance events are logged with metadata
  func testScreenViewLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let swiftUILogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.swiftui" }
    let screenViewLogs = swiftUILogs.flatMap(\.logRecords).filter { $0.eventName == "app.screen.view_did_appear" }

    XCTAssertEqual(screenViewLogs.count, 2, "Should have 2 SwiftUI view_did_appear logs")

    for log in screenViewLogs {
      XCTAssertNotNil(log.attributes.first { $0.key == "screen.name" }?.value.stringValue)
      XCTAssertEqual(log.attributes.first { $0.key == "app.screen.type" }?.value.stringValue, "swiftui")
      XCTAssertNotNil(log.attributes.first { $0.key == "app.screen.interaction" }?.value.intValue)
      XCTAssertNotNil(log.attributes.first { $0.key == "app.screen.parent_screen.name" }?.value.stringValue)
      XCTAssertNotNil(log.attributes.first { $0.key == "session.id" }?.value.stringValue)
      XCTAssertNotNil(log.attributes.first { $0.key == "user.id" }?.value.stringValue)
    }

    // Check for specific view logs
    let tabBarViewLog = screenViewLogs.first { log in
      log.attributes.contains { $0.key == "screen.name" && $0.value.stringValue == "TabBarView" }
    }
    XCTAssertNotNil(tabBarViewLog, "TabBarView log should exist")

    let contentViewLog = screenViewLogs.first { log in
      log.attributes.contains { $0.key == "screen.name" && $0.value.stringValue == "ContentView" }
    }
    XCTAssertNotNil(contentViewLog, "ContentView log should exist")
  }

  // Verifies SwiftUI view appearance timing spans for all screens
  func testScreenTimeToFirstAppearSpansExist() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let swiftUISpans = spans.filter { $0.scope.name == "software.amazon.opentelemetry.swiftui" }
    let screenSpans = swiftUISpans.flatMap(\.spans).filter { $0.name == "app.screen.time_to_first_appear" }

    XCTAssertEqual(screenSpans.count, 4, "Should have 4 SwiftUI screen spans")

    for span in screenSpans {
      XCTAssertNotNil(span.attributes.first { $0.key == "screen.name" }?.value.stringValue)
      XCTAssertEqual(span.attributes.first { $0.key == "app.screen.type" }?.value.stringValue, "swiftui")
      XCTAssertNotNil(span.attributes.first { $0.key == "user.id" }?.value.stringValue)
    }

    // Check for all expected SwiftUI views
    let expectedViews = ["TabBarView", "LoaderView", "ContentView", "HomeScreen"]
    for viewName in expectedViews {
      let viewSpan = screenSpans.first { span in
        span.attributes.contains { $0.key == "screen.name" && $0.value.stringValue == viewName }
      }
      XCTAssertNotNil(viewSpan, "\(viewName) span should exist")
    }
  }

  // Verifies screen navigation parent-child relationships are tracked
  func testParentScreenLinking() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let swiftUILogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.swiftui" }
    let viewDidAppearLogs = swiftUILogs.flatMap(\.logRecords)
      .filter { $0.eventName == "app.screen.view_did_appear" }
      .sorted { UInt64($0.observedTimeUnixNano ?? $0.timeUnixNano) ?? 0 < UInt64($1.observedTimeUnixNano ?? $1.timeUnixNano) ?? 0 }

    XCTAssertEqual(viewDidAppearLogs.count, 2, "Should have 2 view_did_appear logs")

    // Check parent linking
    if viewDidAppearLogs.count >= 2 {
      let firstLog = viewDidAppearLogs[0]
      let secondLog = viewDidAppearLogs[1]

      let firstScreenName = firstLog.attributes.first { $0.key == "screen.name" }?.value.stringValue
      let secondParentName = secondLog.attributes.first { $0.key == "app.screen.parent_screen.name" }?.value.stringValue

      XCTAssertEqual(firstScreenName, "TabBarView", "First screen should be TabBarView")
      XCTAssertEqual(secondParentName, "HomeScreen", "Second screen parent should be HomeScreen")
    }
  }
}
