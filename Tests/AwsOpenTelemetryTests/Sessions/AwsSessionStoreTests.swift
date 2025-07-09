import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionStoreTests: XCTestCase {
  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.idKey)
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.expiryKey)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.idKey)
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.expiryKey)
    super.tearDown()
  }

  func testSaveAndLoadSession() {
    let sessionId = "test-session-123"
    let expires = Date(timeIntervalSinceNow: 1800)
    let session = AwsSession(id: sessionId, expires: expires)

    // Save session
    AwsSessionStore.save(session: session)

    // Load session
    let loadedSession = AwsSessionStore.load()

    XCTAssertNotNil(loadedSession)
    XCTAssertEqual(loadedSession?.id, sessionId)
    XCTAssertEqual(loadedSession?.expires, expires)
  }

  func testLoadSessionWhenNothingSaved() {
    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession, "Should return nil when no session is saved")
  }

  func testLoadSessionMissingId() {
    // Save only expires, not ID
    UserDefaults.standard.set(Date(), forKey: AwsSessionStore.expiryKey)

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession, "Should return nil when ID is missing")
  }

  func testLoadSessionMissingExpiry() {
    // Save only ID, not expires
    UserDefaults.standard.set("test-id", forKey: AwsSessionStore.idKey)

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession, "Should return nil when expires is missing")
  }

  func testSaveOverwritesPreviousSession() {
    let session1 = AwsSession(id: "session-1", expires: Date())
    let session2 = AwsSession(id: "session-2", expires: Date(timeIntervalSinceNow: 1800))

    // Save first session
    AwsSessionStore.save(session: session1)
    let loaded1 = AwsSessionStore.load()
    XCTAssertEqual(loaded1?.id, "session-1")

    // Save second session (should overwrite)
    AwsSessionStore.save(session: session2)
    let loaded2 = AwsSessionStore.load()
    XCTAssertEqual(loaded2?.id, "session-2")
    XCTAssertNotEqual(loaded2?.id, loaded1?.id)
  }

  func testStoreKeys() {
    XCTAssertEqual(AwsSessionStore.idKey, "aws-rum-session-id")
    XCTAssertEqual(AwsSessionStore.expiryKey, "aws-rum-session-expires")
  }

  func testLoadWithCorruptedData() {
    // Set invalid data types
    UserDefaults.standard.set(123, forKey: AwsSessionStore.idKey) // Should be string
    UserDefaults.standard.set("invalid-date", forKey: AwsSessionStore.expiryKey) // Should be Date

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession, "Should return nil when data is corrupted")
  }
}
