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
    spanProcessor = AwsUIDSpanProcessor(uidManager: AwsUIDManager())
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

  func testOnStartWithDifferentUIDs() {
    // Set first UID in UserDefaults
    UserDefaults.standard.set("uid-1", forKey: "aws-rum-user-id")
    let mockUIDManager1 = AwsUIDManager()
    let processor1 = AwsUIDSpanProcessor(uidManager: mockUIDManager1)
    processor1.onStart(parentContext: nil, span: mockSpan)

    // Set second UID in UserDefaults
    UserDefaults.standard.set("uid-2", forKey: "aws-rum-user-id")
    let mockUIDManager2 = AwsUIDManager()
    let processor2 = AwsUIDSpanProcessor(uidManager: mockUIDManager2)
    let mockSpan2 = MockReadableSpan()
    processor2.onStart(parentContext: nil, span: mockSpan2)

    if case let .string(uid1) = mockSpan.capturedAttributes["user.id"] {
      XCTAssertEqual(uid1, "uid-1")
    } else {
      XCTFail("Expected first span to have uid-1")
    }

    if case let .string(uid2) = mockSpan2.capturedAttributes["user.id"] {
      XCTAssertEqual(uid2, "uid-2")
    } else {
      XCTFail("Expected second span to have uid-2")
    }
  }

  func testOnEndDoesNothing() {
    spanProcessor.onEnd(span: mockSpan)
    // No assertions needed - just verify it doesn't crash
  }

  func testShutdownDoesNothing() {
    spanProcessor.shutdown(explicitTimeout: 5.0)
    // No assertions needed - just verify it doesn't crash
  }

  func testForceFlushDoesNothing() {
    spanProcessor.forceFlush(timeout: 5.0)
    // No assertions needed - just verify it doesn't crash
  }

  func testConcurrentOnStartThreadSafety() {
    let group = DispatchGroup()
    let mockUIDManager = AwsUIDManager()
    let processor = AwsUIDSpanProcessor(uidManager: mockUIDManager)
    var spans: [MockReadableSpan] = []
    let syncQueue = DispatchQueue(label: "test.sync")

    for _ in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        let span = MockReadableSpan()
        processor.onStart(parentContext: nil, span: span)
        syncQueue.async {
          spans.append(span)
          group.leave()
        }
      }
    }

    group.wait()

    syncQueue.sync {
      XCTAssertEqual(spans.count, 100)
      let expectedUID = mockUIDManager.getUID()
      for span in spans {
        XCTAssertTrue(span.capturedAttributes.keys.contains("user.id"))
        if case let .string(uid) = span.capturedAttributes["user.id"] {
          XCTAssertEqual(uid, expectedUID)
        } else {
          XCTFail("Expected user.id to be a string")
        }
      }
    }
  }
}
