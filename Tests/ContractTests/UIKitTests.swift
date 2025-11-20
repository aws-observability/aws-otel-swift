import XCTest
@testable import AwsOpenTelemetryCore

class UIKitTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // Verifies UIKit view controller appearance timing is tracked
  func testUIKitTimeToFirstAppearSpanExists() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let uikitSpans = spans.filter { $0.scope.name == "software.amazon.opentelemetry.uikit" }
    let uikitScreenSpan = uikitSpans.flatMap(\.spans).first { $0.name == "app.screen.time_to_first_appear" }

    XCTAssertNotNil(uikitScreenSpan, "UIKit screen span should exist")
    XCTAssertEqual(uikitScreenSpan?.attributes.first { $0.key == "app.screen.type" }?.value.stringValue, "uikit")
    XCTAssertEqual(uikitScreenSpan?.attributes.first { $0.key == "screen.name" }?.value.stringValue, "RootViewController")
    XCTAssertNotNil(uikitScreenSpan?.attributes.first { $0.key == "session.id" }?.value.stringValue)
    XCTAssertNotNil(uikitScreenSpan?.attributes.first { $0.key == "user.id" }?.value.stringValue)
  }
}
