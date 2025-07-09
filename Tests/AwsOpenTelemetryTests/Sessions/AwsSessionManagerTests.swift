import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionManagerTests: XCTestCase {
  var sessionManager: AwsSessionManager!

  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.idKey)
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.expiryKey)
    sessionManager = AwsSessionManager()
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.idKey)
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.expiryKey)
    super.tearDown()
  }

  // when get session and then session is created
  func testGetSession() {
    let session = sessionManager.getSession()
    XCTAssertNotNil(session)
    XCTAssertNotNil(session.id)
    XCTAssertNotNil(session.expires)
  }

  // when get session id then same as get session
  func testGetSessionId() {
    let id1 = sessionManager.getSessionId()
    let id2 = sessionManager.getSessionId()
    XCTAssertEqual(id1, id2)
  }

  // when get session and there is a current session then session is renewed
  func testGetSessionRenewed() {
    let t1 = sessionManager.getSession().expires
    let t2 = sessionManager.getSession().expires
    XCTAssertGreaterThan(t2, t1)
  }

  // when session is expired then new session is created
  func testGetSessionExpired() {
    sessionManager = AwsSessionManager(sessionLength: 0)
    let id1 = sessionManager.getSessionId()
    let id2 = sessionManager.getSessionId()
    XCTAssertNotEqual(id1, id2)
  }

  // when initialized then previous session is restored
  func testGetSessionRestored() {
    let id1 = sessionManager.getSessionId()
    sessionManager = AwsSessionManager()
    let id2 = sessionManager.getSessionId()
    XCTAssertEqual(id1, id2)
  }

  // when get session then session is saved to disk (user defaults object)
  func testGetSessionSavedToDisk() {
    let id1 = sessionManager.getSessionId()
    let id2 = UserDefaults.standard.object(forKey: AwsSessionStore.idKey) as? String
    XCTAssertEqual(id1, id2)
  }

  // when session store is missing expires then session is not recoverable
  func testLoadSessionMissingExpiry() {
    // setup
    let id1 = "session-1"
    UserDefaults.standard.set(id1, forKey: AwsSessionStore.idKey)
    XCTAssertNil(AwsSessionStore.load())

    // run
    sessionManager = AwsSessionManager()
    let id2 = sessionManager.getSessionId()
    XCTAssertNotEqual(id1, id2)
  }

  // when session store is missing id then session is not recoverable
  func testLoadSessionMissingID() {
    // setup
    let expiry1 = Date()
    UserDefaults.standard.set(expiry1, forKey: AwsSessionStore.expiryKey)
    XCTAssertNil(AwsSessionStore.load())

    // run
    sessionManager = AwsSessionManager()
    let expiry2 = sessionManager.getSession().expires
    XCTAssertNotEqual(expiry1, expiry2)
  }

  func testPeekSessionWithoutSession() {
    XCTAssertNil(sessionManager.peekSession(), "Peek should return nil when no session exists")
    XCTAssertNil(sessionManager.peekSessionId(), "Peek session ID should return nil when no session exists")
  }

  func testPeekSessionWithExistingSession() {
    // Create a session first
    let session = sessionManager.getSession()

    // Peek should return the same session without extending it
    let peekedSession = sessionManager.peekSession()
    let peekedSessionId = sessionManager.peekSessionId()

    XCTAssertNotNil(peekedSession)
    XCTAssertEqual(peekedSession?.id, session.id)
    XCTAssertEqual(peekedSession?.expires, session.expires)
    XCTAssertEqual(peekedSessionId, session.id)
  }

  func testPeekDoesNotExtendSession() {
    // Create a session
    let originalSession = sessionManager.getSession()

    // Wait a brief moment
    Thread.sleep(forTimeInterval: 0.01)

    // Peek should not extend the session
    let peekedSession = sessionManager.peekSession()

    XCTAssertEqual(peekedSession?.expires, originalSession.expires, "Peek should not extend session expires")
  }

  func testConfigureWithCustomSessionLength() {
    let customLength: Double = 60 // 1 minute
    sessionManager.configure(sessionLength: customLength)

    let session1 = sessionManager.getSession()
    let expectedExpiry = Date(timeIntervalSinceNow: customLength)

    // Allow for small timing differences (within 1 second)
    XCTAssertEqual(session1.expires.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 1.0)
  }

  func testConfigureWithNilUsesDefault() {
    sessionManager.configure(sessionLength: nil)

    let session = sessionManager.getSession()
    let expectedExpiry = Date(timeIntervalSinceNow: AwsSessionManager.defaultSessionLength)

    // Allow for small timing differences (within 1 second)
    XCTAssertEqual(session.expires.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 1.0)
  }

  func testThreadSafety() {
    let expectation = XCTestExpectation(description: "Thread safety test")
    expectation.expectedFulfillmentCount = 10

    var sessionIds: [String] = []
    let queue = DispatchQueue.global(qos: .default)
    let group = DispatchGroup()

    // Launch multiple concurrent requests
    for _ in 0 ..< 10 {
      group.enter()
      queue.async {
        let sessionId = self.sessionManager.getSessionId()
        DispatchQueue.main.async {
          sessionIds.append(sessionId)
          expectation.fulfill()
          group.leave()
        }
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // All session IDs should be the same (same session)
    let uniqueIds = Set(sessionIds)
    XCTAssertEqual(uniqueIds.count, 1, "All concurrent requests should get the same session ID")
  }
}
