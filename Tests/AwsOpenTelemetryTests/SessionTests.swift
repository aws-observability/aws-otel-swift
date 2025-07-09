import XCTest
@testable import AwsOpenTelemetryCore

final class SessionTests: XCTestCase {
  var sessionManager = AwsSessionManager()

  override func setUp() {
    sessionManager = AwsSessionManager()
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.idKey)
    UserDefaults.standard.removeObject(forKey: AwsSessionStore.expiryKey)
  }

  func testSessionEquality() {
    let session1 = AwsSession(id: "1", expires: Date())
    let session2 = AwsSession(id: "1", expires: Date())
    XCTAssertEqual(session1, session2)
  }

  func testSessionInequality() {
    let session1 = AwsSession(id: "1", expires: Date())
    let session2 = AwsSession(id: "2", expires: Date())
    XCTAssertNotEqual(session1, session2)
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
}
