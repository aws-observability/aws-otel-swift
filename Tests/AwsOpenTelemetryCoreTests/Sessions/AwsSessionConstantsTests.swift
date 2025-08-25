import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionConstantsTests: XCTestCase {
  func testSessionEventConstants() {
    XCTAssertEqual(AwsSessionConstants.sessionStartEvent, "session.start")
    XCTAssertEqual(AwsSessionConstants.sessionEndEvent, "session.end")
    XCTAssertEqual(AwsSessionConstants.id, "session.id")
    XCTAssertEqual(AwsSessionConstants.previousId, "session.previous_id")
    XCTAssertEqual(AwsSessionConstants.startTime, "session.start_time")
    XCTAssertEqual(AwsSessionConstants.endTime, "session.end_time")
    XCTAssertEqual(AwsSessionConstants.duration, "session.duration")
    XCTAssertEqual(AwsSessionConstants.sessionEventNotification, "aws-otel-swift.AwsSessionEvent")
  }
}
