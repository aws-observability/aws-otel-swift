import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionTests: XCTestCase {
  func testSessionInitialization() {
    let id = "test-session-id"
    let expires = Date(timeIntervalSinceNow: 1800) // 30 minutes from now

    let session = AwsSession(id: id, expires: expires)

    XCTAssertEqual(session.id, id)
    XCTAssertEqual(session.expires, expires)
  }

  func testSessionEquality() {
    let id = "test-session-id"
    let expiry1 = Date()
    let expiry2 = Date(timeIntervalSinceNow: 1800)

    let session1 = AwsSession(id: id, expires: expiry1)
    let session2 = AwsSession(id: id, expires: expiry2)

    XCTAssertEqual(session1, session2, "Sessions with same ID should be equal regardless of expires")
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
}
