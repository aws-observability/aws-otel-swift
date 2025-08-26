import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsUIDSpanProcessorTests: XCTestCase {
  var spanProcessor: AwsUIDSpanProcessor!
  var mockSpan: MockReadableSpan!

  override func setUp() {
    super.setUp()
    // Clear any existing UID for clean tests
    UserDefaults.standard.removeObject(forKey: "aws-rum-user-id")
    spanProcessor = AwsUIDSpanProcessor()
    mockSpan = MockReadableSpan()
  }

  func testInitialization() {
    XCTAssertTrue(spanProcessor.isStartRequired)
    XCTAssertFalse(spanProcessor.isEndRequired)
  }

  func testOnStartAddsUID() {
    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    XCTAssertTrue(mockSpan.capturedAttributes.keys.contains("user.id"))
    let uidValue = mockSpan.capturedAttributes["user.id"]
    XCTAssertNotNil(uidValue)
  }

  func testUIDConsistencyAcrossSpans() {
    let mockSpan2 = MockReadableSpan()

    spanProcessor.onStart(parentContext: nil, span: mockSpan)
    spanProcessor.onStart(parentContext: nil, span: mockSpan2)

    let uid1 = mockSpan.capturedAttributes["user.id"]
    let uid2 = mockSpan2.capturedAttributes["user.id"]

    XCTAssertEqual(uid1?.description, uid2?.description)
  }
}
