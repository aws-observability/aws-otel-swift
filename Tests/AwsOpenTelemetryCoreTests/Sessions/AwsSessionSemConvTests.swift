import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionSemConvTests: XCTestCase {
  func testSessionEventConstants() {
    XCTAssertEqual(AwsSessionStartSemConv.name, "session.start")
    XCTAssertEqual(AwsSessionEndSemConv.name, "session.end")
  }

  func testSessionAttributeConstants() {
    XCTAssertEqual(AwsSessionSemConv.id, "session.id")
    XCTAssertEqual(AwsSessionSemConv.previousId, "session.previous_id")
  }
}
