import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionManagerTests: XCTestCase {
  var sessionManager: AwsSessionManager!

  override func setUp() {
    super.setUp()
    sessionManager = AwsSessionManager()
  }

  override func tearDown() {
    AwsSessionStore.testOnlyTeardown()
    super.tearDown()
  }

  // when get session and then session is created
  func testGetSession() {
    let session = sessionManager.getSession()
    XCTAssertNotNil(session)
    XCTAssertNotNil(session.id)
    XCTAssertNotNil(session.expires)
  }

  // when the session is not expired, then getSession returns the same id
  func testGetSessionId() {
    let id1 = sessionManager.getSession().id
    let id2 = sessionManager.getSession().id
    XCTAssertEqual(id1, id2)
  }

  // when get session and there is a current session then session is renewed
  func testGetSessionRenewed() {
    let t1 = sessionManager.getSession().expires
    let t2 = sessionManager.getSession().expires
    XCTAssertGreaterThan(t2, t1)
  }

  // when session is extended during getSession, then the previous id is the same
  func testGetSessionRenewedSamePreviousId() {
    let s = sessionManager.getSession()
    let sExtended = sessionManager.getSession()

    XCTAssertNil(s.previousId)
    XCTAssertEqual(s.id, sExtended.id)
    XCTAssertNotEqual(s.expires, sExtended.expires)
  }

  // when session is expired then new session is created
  func testGetSessionExpired() {
    sessionManager.configure(sessionTimeout: 0)
    let id1 = sessionManager.getSession().id
    let id2 = sessionManager.getSession().id
    XCTAssertNotEqual(id1, id2)
  }

  // when initialized then previous session is restored
  func testGetSessionRestored() {
    let id1 = sessionManager.getSession().id
    let id2 = sessionManager.getSession().id
    XCTAssertEqual(id1, id2)
  }

  // when get session then session is saved to disk (user defaults object)
  func testGetSessionSavedToDisk() {
    let session = sessionManager.getSession()
    // The first session should be saved immediately according to AwsSessionStore.scheduleSave
    let savedId = UserDefaults.standard.object(forKey: AwsSessionStore.idKey) as? String
    XCTAssertEqual(session.id, savedId)
  }

  // when session store is missing expires then session is not recoverable
  func testLoadSessionMissingExpiry() {
    // setup
    let id1 = "session-1"
    UserDefaults.standard.set(id1, forKey: AwsSessionStore.idKey)
    XCTAssertNil(AwsSessionStore.load())

    // run
    sessionManager = AwsSessionManager()
    let id2 = sessionManager.getSession().id
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
    XCTAssertNil(sessionManager.peekSession()?.id, "Peek session ID should return nil when no session exists")
  }

  func testPeekSessionWithExistingSession() {
    // Create a session first
    let session = sessionManager.getSession()

    // Peek should return the same session without extending it
    let peekedSession = sessionManager.peekSession()

    XCTAssertNotNil(peekedSession)
    XCTAssertEqual(peekedSession?.id, session.id)
  }

  func testPeekDoesNotExtendSession() {
    // Create a session
    let originalSession = sessionManager.getSession()

    // Peek should not extend the session
    let peekedSession = sessionManager.peekSession()

    XCTAssertEqual(peekedSession?.expires, originalSession.expires, "Peek should not extend session expires")
  }

  func testConfigureWithCustomSessionLength() {
    let customLength = 60 // 1 minute
    sessionManager.configure(sessionTimeout: customLength)

    let session1 = sessionManager.getSession()
    let expectedExpiry = Date(timeIntervalSinceNow: Double(customLength))

    // Allow for small timing differences (within 1 second)
    XCTAssertEqual(session1.expires.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 1.0)
  }

  func testConfigureWithNilUsesDefault() {
    sessionManager.configure(sessionTimeout: nil)

    let session = sessionManager.getSession()
    let expectedExpiry = Date(timeIntervalSinceNow: Double(AwsSessionManager.defaultSessionLength))

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
        let sessionId = self.sessionManager.getSession().id
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

  func testNewSessionHasNoPreviousId() {
    let session = sessionManager.getSession()
    XCTAssertNil(session.previousId, "First session should have no previous ID")
  }

  func testExpiredSessionCreatesPreviousId() {
    sessionManager.configure(sessionTimeout: 0)
    let firstSession = sessionManager.peekSession()!
    let secondSession = sessionManager.getSession()
    let thirdSession = sessionManager.getSession()

    XCTAssertNil(firstSession.previousId, "First session should have no previous ID")
    XCTAssertEqual(secondSession.previousId, firstSession.id, "Second session should have first as previous")
    XCTAssertEqual(thirdSession.previousId, secondSession.id, "Third session should have second as previous")
  }
}
