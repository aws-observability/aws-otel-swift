import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionTests: XCTestCase {
  func testSessionInitialization() {
    let id = "test-session-id"
    let expires = Date(timeIntervalSinceNow: 1800) // 30 minutes from now

    let session = AwsSession(id: id, expires: expires)

    XCTAssertEqual(session.id, id)
    XCTAssertEqual(session.expires, expires)
    XCTAssertNil(session.previousId, "Default initialization should have nil previousId")
  }

  func testSessionEquality() {
    let id = "test-session-id"
    let expires = Date()
    let previousId = "prev-id"

    let session1 = AwsSession(id: id, expires: expires, previousId: previousId)
    let session2 = AwsSession(id: id, expires: expires, previousId: previousId)

    XCTAssertEqual(session1, session2, "Sessions with same ID, expires, and previousId should be equal")
  }

  func testSessionInequality() {
    let expires = Date()
    let session1 = AwsSession(id: "session-1", expires: expires)
    let session2 = AwsSession(id: "session-2", expires: expires)

    XCTAssertNotEqual(session1, session2, "Sessions with different IDs should not be equal")
  }

  func testSessionNotExpired() {
    let futureExpiry = Date(timeIntervalSinceNow: 1800) // 30 minutes from now
    let session = AwsSession(id: "test-id", expires: futureExpiry)

    XCTAssertFalse(session.isExpired(), "Session with future expires should not be expired")
  }

  func testSessionExpired() {
    let pastExpiry = Date(timeIntervalSinceNow: -1800) // 30 minutes ago
    let session = AwsSession(id: "test-id", expires: pastExpiry)

    XCTAssertTrue(session.isExpired(), "Session with past expires should be expired")
  }

  func testSessionExpiryAtExactTime() {
    let currentTime = Date()
    let session = AwsSession(id: "test-id", expires: currentTime)

    // Sleep briefly to ensure current time is past expiry
    Thread.sleep(forTimeInterval: 0.001)

    XCTAssertTrue(session.isExpired(), "Session expiring at current time should be considered expired")
  }

  func testSessionWithPreviousId() {
    let id = "current-session"
    let previousId = "previous-session"
    let expires = Date(timeIntervalSinceNow: 1800)

    let session = AwsSession(id: id, expires: expires, previousId: previousId)

    XCTAssertEqual(session.id, id)
    XCTAssertEqual(session.previousId, previousId)
    XCTAssertEqual(session.expires, expires)
  }

  func testSessionInequalityWithDifferentPreviousId() {
    let id = "test-session"
    let expires = Date()

    let session1 = AwsSession(id: id, expires: expires, previousId: "prev-1")
    let session2 = AwsSession(id: id, expires: expires, previousId: "prev-2")
    let session3 = AwsSession(id: id, expires: expires, previousId: nil)

    XCTAssertNotEqual(session1, session2, "Sessions with different previousId should not be equal")
    XCTAssertNotEqual(session1, session3, "Sessions with different previousId should not be equal")
  }

  func testSessionInequalityWithDifferentExpires() {
    let id = "test-session-id"
    let expiry1 = Date()
    let expiry2 = Date(timeIntervalSinceNow: 1800)

    let session1 = AwsSession(id: id, expires: expiry1)
    let session2 = AwsSession(id: id, expires: expiry2)

    XCTAssertNotEqual(session1, session2, "Sessions with different expires should not be equal")
  }

  func testSessionWithNilPreviousId() {
    let id = "current-session"
    let expires = Date(timeIntervalSinceNow: 1800)

    let session = AwsSession(id: id, expires: expires, previousId: nil)

    XCTAssertEqual(session.id, id)
    XCTAssertNil(session.previousId)
  }
}
