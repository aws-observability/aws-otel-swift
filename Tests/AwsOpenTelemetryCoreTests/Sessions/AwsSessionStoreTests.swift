import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionStoreTests: XCTestCase {
  override func tearDown() {
    AwsSessionStore.teardown()
    super.tearDown()
  }

  func testSaveAndLoadSession() {
    let sessionId = "test-session-123"
    let expireTime = Date(timeIntervalSinceNow: 1800)
    let startTime = Date(timeIntervalSinceNow: -300)
    let session = AwsSession(id: sessionId, expireTime: expireTime, previousId: nil, startTime: startTime)

    AwsSessionStore.scheduleSave(session: session)
    let loadedSession = AwsSessionStore.load()

    XCTAssertNotNil(loadedSession)
    XCTAssertEqual(loadedSession?.id, sessionId)
    XCTAssertEqual(loadedSession?.expireTime, expireTime)
    XCTAssertEqual(loadedSession?.startTime, startTime)
    XCTAssertNil(loadedSession?.previousId)
  }

  func testLoadSessionWhenNothingSaved() {
    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testLoadSessionMissingId() {
    UserDefaults.standard.set(Date(), forKey: AwsSessionStore.expireTimeKey)
    UserDefaults.standard.set(Date(), forKey: AwsSessionStore.startTimeKey)
    UserDefaults.standard.set(1800, forKey: AwsSessionStore.sessionTimeoutKey)

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testLoadSessionMissingExpiry() {
    UserDefaults.standard.set("test-id", forKey: AwsSessionStore.idKey)
    UserDefaults.standard.set(Date(), forKey: AwsSessionStore.startTimeKey)
    UserDefaults.standard.set(1800, forKey: AwsSessionStore.sessionTimeoutKey)

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testLoadSessionMissingStartTime() {
    UserDefaults.standard.set("test-id", forKey: AwsSessionStore.idKey)
    UserDefaults.standard.set(Date(), forKey: AwsSessionStore.expireTimeKey)
    UserDefaults.standard.set(1800, forKey: AwsSessionStore.sessionTimeoutKey)

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testSaveOverwritesPreviousSession() {
    let session1 = AwsSession(id: "session-1", expireTime: Date(), previousId: nil, startTime: Date(), sessionTimeout: 1800)
    let session2 = AwsSession(id: "session-2", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date(), sessionTimeout: 1800)

    AwsSessionStore.saveImmediately(session: session1)
    let loaded1 = AwsSessionStore.load()
    XCTAssertEqual(loaded1?.id, "session-1")

    AwsSessionStore.saveImmediately(session: session2)
    let loaded2 = AwsSessionStore.load()
    XCTAssertEqual(loaded2?.id, "session-2")
  }

  func testStoreKeys() {
    XCTAssertEqual(AwsSessionStore.idKey, "aws-rum-session-id")
    XCTAssertEqual(AwsSessionStore.expireTimeKey, "aws-rum-session-expire-time")
    XCTAssertEqual(AwsSessionStore.startTimeKey, "aws-rum-session-start-time")
    XCTAssertEqual(AwsSessionStore.previousIdKey, "aws-rum-session-previous-id")
    XCTAssertEqual(AwsSessionStore.sessionTimeoutKey, "aws-rum-session-timeout")
  }

  func testLoadWithCorruptedData() {
    UserDefaults.standard.set(123, forKey: AwsSessionStore.idKey)
    UserDefaults.standard.set("invalid-date", forKey: AwsSessionStore.expireTimeKey)

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testSaveAndLoadSessionWithPreviousId() {
    let sessionId = "current-session-123"
    let previousId = "previous-session-456"
    let expireTime = Date(timeIntervalSinceNow: 1800)
    let session = AwsSession(id: sessionId, expireTime: expireTime, previousId: previousId, startTime: Date(), sessionTimeout: 1800)

    AwsSessionStore.scheduleSave(session: session)
    let loadedSession = AwsSessionStore.load()

    XCTAssertNotNil(loadedSession)
    XCTAssertEqual(loadedSession?.id, sessionId)
    XCTAssertEqual(loadedSession?.previousId, previousId)
    XCTAssertEqual(loadedSession?.expireTime, expireTime)
  }

  func testScheduleSaveImmediatelySavesFirstSession() {
    let session = AwsSession(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date(), sessionTimeout: 1800)
    AwsSessionStore.scheduleSave(session: session)

    let savedId = UserDefaults.standard.string(forKey: AwsSessionStore.idKey)
    XCTAssertEqual(savedId, session.id)
  }

  func testTeardownClearsUserDefaults() {
    let session = AwsSession(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date(), sessionTimeout: 1800)
    AwsSessionStore.saveImmediately(session: session)

    XCTAssertNotNil(UserDefaults.standard.string(forKey: AwsSessionStore.idKey))

    AwsSessionStore.teardown()

    XCTAssertNil(UserDefaults.standard.string(forKey: AwsSessionStore.idKey))
    XCTAssertNil(UserDefaults.standard.object(forKey: AwsSessionStore.expireTimeKey))
    XCTAssertNil(UserDefaults.standard.object(forKey: AwsSessionStore.startTimeKey))
    XCTAssertNil(UserDefaults.standard.string(forKey: AwsSessionStore.previousIdKey))
    XCTAssertNil(UserDefaults.standard.object(forKey: AwsSessionStore.sessionTimeoutKey))
  }

  func testTeardownInvalidatesTimer() {
    let session = AwsSession(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date(), sessionTimeout: 1800)
    AwsSessionStore.scheduleSave(session: session)

    AwsSessionStore.teardown()

    let session2 = AwsSession(id: "test-session-2", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date())
    AwsSessionStore.scheduleSave(session: session2)

    let savedId = UserDefaults.standard.string(forKey: AwsSessionStore.idKey)
    XCTAssertEqual(savedId, session2.id)
  }

  func testLoadSessionMissingTimeout() {
    UserDefaults.standard.set("test-id", forKey: AwsSessionStore.idKey)
    UserDefaults.standard.set(Date(), forKey: AwsSessionStore.expireTimeKey)
    UserDefaults.standard.set(Date(), forKey: AwsSessionStore.startTimeKey)

    let loadedSession = AwsSessionStore.load()
    XCTAssertNil(loadedSession, "Session should be nil when timeout is missing")
  }
}
