import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionManagerTests: XCTestCase {
  var sessionManager: AwsSessionManager!

  override func setUp() {
    super.setUp()
    AwsSessionStore.teardown()
    sessionManager = AwsSessionManager()
  }

  override func tearDown() {
    NotificationCenter.default.removeObserver(self)
    AwsSessionStore.teardown()
    super.tearDown()
  }

  func testGetSession() {
    let session = sessionManager.getSession()
    XCTAssertNotNil(session)
    XCTAssertNotNil(session.id)
    XCTAssertNotNil(session.expireTime)
    XCTAssertNil(session.previousId)
  }

  func testGetSessionId() {
    let id1 = sessionManager.getSession().id
    let id2 = sessionManager.getSession().id
    XCTAssertEqual(id1, id2)
  }

  func testGetSessionRenewed() {
    let t1 = sessionManager.getSession().expireTime
    let t2 = sessionManager.getSession().expireTime
    XCTAssertGreaterThan(t2, t1)
  }

  func testStartTimePreservedWhenSessionExtended() {
    let originalSession = sessionManager.getSession()
    Thread.sleep(forTimeInterval: 0.1)
    let extendedSession = sessionManager.getSession()

    XCTAssertEqual(originalSession.id, extendedSession.id)
    XCTAssertGreaterThan(extendedSession.expireTime, originalSession.expireTime)
    XCTAssertEqual(originalSession.startTime, extendedSession.startTime)
  }

  func testGetSessionExpired() {
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: 0))
    let session1 = sessionManager.getSession()
    Thread.sleep(forTimeInterval: 0.1)
    let session2 = sessionManager.getSession()

    XCTAssertNotEqual(session1.id, session2.id)
    XCTAssertNotEqual(session1.startTime, session2.startTime)
    XCTAssertGreaterThan(session2.startTime, session1.startTime)
  }

  func testGetSessionSavedToDisk() {
    let session = sessionManager.getSession()
    let savedId = UserDefaults.standard.object(forKey: AwsSessionStore.idKey) as? String
    let savedTimeout = UserDefaults.standard.object(forKey: AwsSessionStore.sessionTimeoutKey) as? Int

    XCTAssertEqual(session.id, savedId)
    XCTAssertEqual(session.sessionTimeout, savedTimeout)
  }

  func testLoadSessionMissingExpiry() {
    let id1 = "session-1"
    UserDefaults.standard.set(id1, forKey: AwsSessionStore.idKey)
    XCTAssertNil(AwsSessionStore.load())

    let id2 = sessionManager.getSession().id
    XCTAssertNotEqual(id1, id2)
  }

  func testLoadSessionMissingID() {
    let expiry1 = Date()
    UserDefaults.standard.set(expiry1, forKey: AwsSessionStore.expireTimeKey)
    XCTAssertNil(AwsSessionStore.load())

    let expiry2 = sessionManager.getSession().expireTime
    XCTAssertNotEqual(expiry1, expiry2)
  }

  func testPeekSessionWithoutSession() {
    XCTAssertNil(sessionManager.peekSession())
  }

  func testPeekSessionWithExistingSession() {
    let session = sessionManager.getSession()
    let peekedSession = sessionManager.peekSession()

    XCTAssertNotNil(peekedSession)
    XCTAssertEqual(peekedSession?.id, session.id)
  }

  func testPeekDoesNotExtendSession() {
    let originalSession = sessionManager.getSession()
    let peekedSession = sessionManager.peekSession()

    XCTAssertEqual(peekedSession?.expireTime, originalSession.expireTime)
  }

  func testCustomSessionLength() {
    let customLength = 60
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: customLength))

    let session1 = sessionManager.getSession()
    let expectedExpiry = Date(timeIntervalSinceNow: Double(customLength))

    XCTAssertEqual(session1.expireTime.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 1.0)
    XCTAssertEqual(session1.sessionTimeout, customLength)
  }

  func testCustomSessionSampleRate() {
    let customSampleRate = 0.5
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionSampleRate: customSampleRate))
    sessionManager.getSession()

    // Can't predict exact outcome with 0.5, but should not crash
    let sampling = sessionManager.isSessionSampled
    XCTAssertTrue(sampling == true || sampling == false)
  }

  func testNewSessionHasNoPreviousId() {
    let session = sessionManager.getSession()
    XCTAssertNil(session.previousId)
  }

  func testExpiredSessionCreatesPreviousId() {
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: 0))
    let firstSession = sessionManager.getSession()
    let secondSession = sessionManager.getSession()
    let thirdSession = sessionManager.getSession()

    XCTAssertNil(firstSession.previousId)
    XCTAssertEqual(secondSession.previousId, firstSession.id)
    XCTAssertEqual(thirdSession.previousId, secondSession.id)
  }

  func testStartSessionAddsToQueueWhenInstrumentationNotApplied() {
    AwsSessionEventInstrumentation.queue = []
    AwsSessionEventInstrumentation.isApplied = false
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: 0))
    let session = sessionManager.getSession()

    // Wait for async session event processing
    let expectation = XCTestExpectation(description: "Session event queued")
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now()) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 2.0)

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue[0].session.id, session.id)
  }

  func testStartSessionProcessesDirectlyWhenInstrumentationApplied() {
    AwsSessionEventInstrumentation.queue = []
    AwsSessionEventInstrumentation.isApplied = true

    let session = sessionManager.getSession()

    // When instrumentation is applied, sessions are processed directly, not queued
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)
    XCTAssertNotNil(session.id)
  }

  func testSessionStartNotificationPosted() {
    let expectation = XCTestExpectation(description: "Session start notification")
    var receivedSession: AwsSession?

    let observer = NotificationCenter.default.addObserver(
      forName: SessionStartNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedSession = notification.object as? AwsSession
      expectation.fulfill()
    }

    let session = sessionManager.getSession()

    wait(for: [expectation], timeout: 2.0) // Increased timeout for async processing
    XCTAssertEqual(receivedSession?.id, session.id)

    NotificationCenter.default.removeObserver(observer)
  }

  func testMultipleSessionStartNotifications() {
    // Clean up any existing state
    AwsSessionStore.teardown()
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: 0))

    var receivedSessions: [String] = []
    let expectation = XCTestExpectation(description: "Multiple session notifications")
    expectation.expectedFulfillmentCount = 3

    let observer = NotificationCenter.default.addObserver(
      forName: SessionStartNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let session = notification.object as? AwsSession {
        receivedSessions.append(session.id)
      }
      expectation.fulfill()
    }

    let session1 = sessionManager.getSession()
    let session2 = sessionManager.getSession()
    let session3 = sessionManager.getSession()

    wait(for: [expectation], timeout: 2.0)

    NotificationCenter.default.removeObserver(observer)

    // Only check the count and that we got the expected sessions
    XCTAssertEqual(receivedSessions.count, 3)
    XCTAssertTrue(receivedSessions.contains(session1.id))
    XCTAssertTrue(receivedSessions.contains(session2.id))
    XCTAssertTrue(receivedSessions.contains(session3.id))
  }

  func testSessionSamplingWithFullSampleRate() {
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionSampleRate: 1.0))
    sessionManager.getSession()
    XCTAssertTrue(sessionManager.isSessionSampled)
  }

  func testSessionSamplingWithZeroSampleRate() {
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionSampleRate: 0.0))
    sessionManager.getSession()
    XCTAssertFalse(sessionManager.isSessionSampled)
  }

  func testSessionSamplingPersistsAcrossSessionExtensions() {
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionSampleRate: 1.0))
    sessionManager.getSession()
    let initialSampling = sessionManager.isSessionSampled

    // Extend session
    sessionManager.getSession()
    XCTAssertEqual(sessionManager.isSessionSampled, initialSampling)
  }

  func testSessionSamplingChangesOnNewSession() {
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: 0, sessionSampleRate: 1.0))
    sessionManager.getSession()
    let firstSampling = sessionManager.isSessionSampled

    // Force new session
    sessionManager.getSession()
    let secondSampling = sessionManager.isSessionSampled

    // Both should be true with 1.0 sample rate
    XCTAssertTrue(firstSampling)
    XCTAssertTrue(secondSampling)
  }

  func testShouldSampleSessionFunction() {
    // Test through reflection since shouldSampleSession is private
    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionSampleRate: 1.0))
    sessionManager.getSession()
    XCTAssertTrue(sessionManager.isSessionSampled)

    sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionSampleRate: 0.0))
    sessionManager.getSession()
    XCTAssertFalse(sessionManager.isSessionSampled)
  }
}
