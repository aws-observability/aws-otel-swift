import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionConstantsTests: XCTestCase {
  func testSessionEventConstants() {
    XCTAssertEqual(AwsSessionConstants.sessionStartEvent, "session.start")
    XCTAssertEqual(AwsSessionConstants.sessionEndEvent, "session.end")
    XCTAssertEqual(AwsSessionConstants.id, "session.id")
    XCTAssertEqual(AwsSessionConstants.previousId, "session.previous_id")
    XCTAssertEqual(AwsSessionConstants.sessionEventNotification, "software.amazon.opentelemetry.AwsSessionEvent")
  }
}
