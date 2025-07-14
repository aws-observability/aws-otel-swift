import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionStoreTests: XCTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    AwsSessionStore.testOnlyTeardown()
    super.tearDown()
  }

  func testSaveAndLoadSession() {
    let sessionId = "test-session-123"
    let expires = Date(timeIntervalSinceNow: 1800)
    let session = AwsSession(id: sessionId, expires: expires)

    // Save session
    AwsSessionStore.scheduleSave(session: session)

    // Load session
    let loadedSession = AwsSessionStore.load()

    XCTAssertNotNil(loadedSession)
    XCTAssertEqual(loadedSession?.id, sessionId)
    XCTAssertEqual(loadedSession?.expires, expires)
    XCTAssertNil(loadedSession?.previousId)
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
    AwsSessionStore.saveImmediately(session: session1)
    let loaded1 = AwsSessionStore.load()
    XCTAssertEqual(loaded1?.id, "session-1")

    // Save second session (should overwrite)
    AwsSessionStore.saveImmediately(session: session2)
    let loaded2 = AwsSessionStore.load()
    XCTAssertEqual(loaded2?.id, "session-2")
    XCTAssertNotEqual(loaded2?.id, loaded1?.id)
  }

  func testStoreKeys() {
    XCTAssertEqual(AwsSessionStore.idKey, "aws-rum-session-id")
    XCTAssertEqual(AwsSessionStore.expiryKey, "aws-rum-session-expires")
    XCTAssertEqual(AwsSessionStore.previousIdKey, "aws-rum-session-previous-id")
  }

  func testLoadWithCorruptedData() {
    // Set invalid data types
    UserDefaults.standard.set(123, forKey: AwsSessionStore.idKey) // Should be string
    UserDefaults.standard.set("invalid-date", forKey: AwsSessionStore.expiryKey) // Should be Date

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession, "Should return nil when data is corrupted")
  }

  func testSaveAndLoadSessionWithPreviousId() {
    let sessionId = "current-session-123"
    let previousId = "previous-session-456"
    let expires = Date(timeIntervalSinceNow: 1800)
    let session = AwsSession(id: sessionId, expires: expires, previousId: previousId)

    AwsSessionStore.scheduleSave(session: session)
    let loadedSession = AwsSessionStore.load()

    XCTAssertNotNil(loadedSession)
    XCTAssertEqual(loadedSession?.id, sessionId)
    XCTAssertEqual(loadedSession?.previousId, previousId)
    XCTAssertEqual(loadedSession?.expires, expires)
  }

  func testSaveAndLoadSessionWithoutPreviousId() {
    let sessionId = "current-session-123"
    let expires = Date(timeIntervalSinceNow: 1800)
    let session = AwsSession(id: sessionId, expires: expires, previousId: nil)

    AwsSessionStore.scheduleSave(session: session)
    let loadedSession = AwsSessionStore.load()

    XCTAssertNotNil(loadedSession)
    XCTAssertEqual(loadedSession?.id, sessionId)
    XCTAssertNil(loadedSession?.previousId)
    XCTAssertEqual(loadedSession?.expires, expires)
  }

  func testSaveSessionRemovesPreviousIdWhenNil() {
    // First save a session with previousId
    let sessionWithPrevious = AwsSession(id: "session-1", expires: Date(), previousId: "prev-1")
    AwsSessionStore.saveImmediately(session: sessionWithPrevious)
    XCTAssertNotNil(UserDefaults.standard.string(forKey: AwsSessionStore.previousIdKey))

    // Then save a session without previousId
    let sessionWithoutPrevious = AwsSession(id: "session-2", expires: Date(), previousId: nil)
    AwsSessionStore.saveImmediately(session: sessionWithoutPrevious)

    let loadedSession = AwsSessionStore.load()
    XCTAssertNotNil(loadedSession, "Loaded session should not be nil")
    XCTAssertNil(loadedSession!.previousId, "Previous ID should be removed when saving session with nil previousId")
  }

  func testScheduleSaveImmediatelySavesFirstSession() {
    let session = AwsSession(id: "test-session", expires: Date(timeIntervalSinceNow: 1800))
    AwsSessionStore.scheduleSave(session: session)

    let savedId = UserDefaults.standard.string(forKey: AwsSessionStore.idKey)
    XCTAssertEqual(savedId, session.id, "First session should be saved immediately")
  }

  func testScheduleSaveWithPreviousId() {
    let session = AwsSession(id: "test-session", expires: Date(timeIntervalSinceNow: 1800), previousId: "prev-session")
    AwsSessionStore.scheduleSave(session: session)

    let savedId = UserDefaults.standard.string(forKey: AwsSessionStore.idKey)
    let savedPreviousId = UserDefaults.standard.string(forKey: AwsSessionStore.previousIdKey)
    XCTAssertEqual(savedId, session.id)
    XCTAssertEqual(savedPreviousId, "prev-session")
  }

  func testTeardownClearsUserDefaults() {
    let session = AwsSession(id: "test-session", expires: Date(timeIntervalSinceNow: 1800))
    AwsSessionStore.saveImmediately(session: session)

    XCTAssertNotNil(UserDefaults.standard.string(forKey: AwsSessionStore.idKey))

    AwsSessionStore.testOnlyTeardown()

    XCTAssertNil(UserDefaults.standard.string(forKey: AwsSessionStore.idKey))
    XCTAssertNil(UserDefaults.standard.object(forKey: AwsSessionStore.expiryKey))
    XCTAssertNil(UserDefaults.standard.string(forKey: AwsSessionStore.previousIdKey))
  }

  func testTeardownInvalidatesTimer() {
    let session = AwsSession(id: "test-session", expires: Date(timeIntervalSinceNow: 1800))
    AwsSessionStore.scheduleSave(session: session)

    AwsSessionStore.testOnlyTeardown()

    let session2 = AwsSession(id: "test-session-2", expires: Date(timeIntervalSinceNow: 1800))
    AwsSessionStore.scheduleSave(session: session2)

    // This is a roundabout way of testing, but session 2 will only be saved immediately if the timer was deleted
    let savedId = UserDefaults.standard.string(forKey: AwsSessionStore.idKey)
    XCTAssertEqual(savedId, session2.id)
  }
}
