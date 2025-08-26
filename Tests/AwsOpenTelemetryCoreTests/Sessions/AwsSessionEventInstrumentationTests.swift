import XCTest
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import TestUtils

final class AwsSessionEventInstrumentationTests: XCTestCase {
  let sessionId1 = "test-session-id-1"
  let sessionId2 = "test-session-id-2"
  let sessionIdExpired = "test-session-id-expired"

  var startTime1: Date!
  var startTime2: Date!
  var logExporter: InMemoryLogRecordExporter!

  lazy var session1 = AwsSession(
    id: sessionId1,
    expireTime: Date().addingTimeInterval(3600),
    previousId: nil,
    startTime: startTime1
  )

  lazy var session2 = AwsSession(
    id: sessionId2,
    expireTime: Date().addingTimeInterval(3600),
    previousId: sessionId1,
    startTime: startTime2
  )

  lazy var sessionExpired = AwsSession(
    id: sessionIdExpired,
    expireTime: Date().addingTimeInterval(-3600)
  )

  override func setUp() {
    super.setUp()

    startTime1 = Date()
    startTime2 = Date().addingTimeInterval(60)

    AwsSessionEventInstrumentation.queue = []
    AwsSessionEventInstrumentation.isApplied = false
    AwsSessionStore.teardown() // Clear any existing session state

    logExporter = InMemoryLogRecordExporter()
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

    NotificationCenter.default.removeObserver(
      self,
      name: AwsSessionEventInstrumentation.sessionEventNotification,
      object: nil
    )
  }

  override func tearDown() {
    super.tearDown()

    NotificationCenter.default.removeObserver(
      self,
      name: AwsSessionEventInstrumentation.sessionEventNotification,
      object: nil
    )

    AwsSessionStore.teardown() // Clean up session state
    OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
  }

  func testQueueInitiallyEmpty() {
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)
    XCTAssertFalse(AwsSessionEventInstrumentation.isApplied)
  }

  func testHandleNewSessionAddsToQueue() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue[0].session.id, sessionId1)
  }

  func testInstrumentationEmptiesQueue() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1)
    AwsSessionEventInstrumentation.addSession(session: session2, eventType: .start)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 2)
    XCTAssertFalse(AwsSessionEventInstrumentation.isApplied)

    _ = AwsSessionEventInstrumentation()

    XCTAssertTrue(AwsSessionEventInstrumentation.isApplied)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)
  }

  func testQueueDoesNotFillAfterApplied() {
    _ = AwsSessionEventInstrumentation()

    AwsSessionEventInstrumentation.addSession(session: session2, eventType: .start)

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)
  }

  func testNotificationPostedAfterInstrumentationApplied() {
    let expectation = XCTestExpectation(description: "Session notification posted")
    var receivedSessionEvent: AwsSessionEvent?

    NotificationCenter.default.addObserver(
      forName: AwsSessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedSessionEvent = notification.object as? AwsSessionEvent
      expectation.fulfill()
    }

    _ = AwsSessionEventInstrumentation()

    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)

    wait(for: [expectation], timeout: 0)

    XCTAssertNotNil(receivedSessionEvent)
    XCTAssertEqual(receivedSessionEvent?.session.id, sessionId1)
    XCTAssertEqual(receivedSessionEvent?.eventType, .start)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)
  }

  func testNotificationNotPostedBeforeInstrumentationApplied() {
    let expectation = XCTestExpectation(description: "Session notification posted")
    expectation.isInverted = true

    NotificationCenter.default.addObserver(
      forName: AwsSessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { _ in
      expectation.fulfill()
    }

    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)

    wait(for: [expectation], timeout: 0.1)

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1)
  }

  func testMultipleInitializationDoesNotProcessQueueTwice() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    AwsSessionEventInstrumentation.addSession(session: session2, eventType: .start)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 2)

    _ = AwsSessionEventInstrumentation()
    XCTAssertTrue(AwsSessionEventInstrumentation.isApplied)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)

    // Second initialization should not process queue again
    AwsSessionEventInstrumentation.queue = [AwsSessionEvent(session: sessionExpired, eventType: .end)]
    _ = AwsSessionEventInstrumentation()
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1) // Queue unchanged
  }

  func testMultipleInitializationDoesNotAddDuplicateObservers() {
    _ = AwsSessionEventInstrumentation()
    _ = AwsSessionEventInstrumentation()

    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
  }

  func testSessionStartLogRecord() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(startTime1.timeIntervalSince1970.toNanoseconds)))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testSessionStartApplyAfter() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(session1.startTime.timeIntervalSince1970.toNanoseconds)))
    XCTAssertNil(record.attributes["session.previous_id"])
    XCTAssertNil(record.attributes["session.end_time"])
    XCTAssertNil(record.attributes["session.duration"])
  }

  func testSessionStartApplyBefore() {
    _ = AwsSessionEventInstrumentation()
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(session1.startTime.timeIntervalSince1970.toNanoseconds)))
    XCTAssertNil(record.attributes["session.previous_id"])
    XCTAssertNil(record.attributes["session.end_time"])
    XCTAssertNil(record.attributes["session.duration"])
  }

  func testSessionEndApplyBefore() {
    _ = AwsSessionEventInstrumentation()
    AwsSessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.end"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(sessionExpired.startTime.timeIntervalSince1970.toNanoseconds)))
    XCTAssertNil(record.attributes["session.previous_id"])
    XCTAssertEqual(record.attributes["session.end_time"], AttributeValue.double(Double(sessionExpired.endTime!.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(record.attributes["session.duration"], AttributeValue.double(Double(sessionExpired.duration!.toNanoseconds)))
  }

  func testSessionStartLogRecordWithPreviousId() {
    AwsSessionEventInstrumentation.addSession(session: session2, eventType: .start)
    _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(startTime2.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(record.attributes["session.previous_id"], AttributeValue.string(sessionId1))
  }

  func testSessionEndLogRecord() {
    AwsSessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)
    _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.end"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(sessionExpired.startTime.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(record.attributes["session.end_time"], AttributeValue.double(Double(sessionExpired.endTime!.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(record.attributes["session.duration"], AttributeValue.double(Double(sessionExpired.duration!.toNanoseconds)))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testInstrumentationScopeName() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(AwsSessionEventInstrumentation.instrumentationKey, "aws-otel-swift.session")
    XCTAssertEqual(logRecords.first?.instrumentationScopeInfo.name, "aws-otel-swift.session")
  }

  func testMultipleSessionsProcessedInOrderAfterinstrumentation() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    AwsSessionEventInstrumentation.addSession(session: session2, eventType: .start)
    AwsSessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 3)

    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
    XCTAssertNil(logRecords[0].attributes["session.previous_id"])

    XCTAssertEqual(logRecords[1].attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(logRecords[1].body, AttributeValue.string("session.start"))
    XCTAssertEqual(logRecords[1].attributes["session.previous_id"], AttributeValue.string(sessionId1))

    XCTAssertEqual(logRecords[2].attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(logRecords[2].body, AttributeValue.string("session.end"))
  }

  func testMultipleSessionsProcessedInOrderBefore() {
    _ = AwsSessionEventInstrumentation()

    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    AwsSessionEventInstrumentation.addSession(session: session2, eventType: .start)
    AwsSessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 3)

    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
    XCTAssertNil(logRecords[0].attributes["session.previous_id"])

    XCTAssertEqual(logRecords[1].attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(logRecords[1].body, AttributeValue.string("session.start"))
    XCTAssertEqual(logRecords[1].attributes["session.previous_id"], AttributeValue.string(sessionId1))

    XCTAssertEqual(logRecords[2].attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(logRecords[2].body, AttributeValue.string("session.end"))
  }

  // MARK: - Max Queue Size Tests

  func testMaxQueueSizeConstant() {
    XCTAssertEqual(AwsSessionEventInstrumentation.maxQueueSize, 32)
  }

  func testQueueEnforcesMaxSize() {
    // Add sessions up to max capacity
    for i in 1 ... 32 {
      let session = AwsSession(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      AwsSessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 32)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.first?.session.id, "session-1")
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.last?.session.id, "session-32")
  }

  func testQueueDropsNewEventsWhenExceedingMaxSize() {
    // Add sessions beyond max capacity
    for i in 1 ... 40 {
      let session = AwsSession(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      AwsSessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 32)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.first?.session.id, "session-1")
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.last?.session.id, "session-32")
  }

  func testMaxQueueSizeWithMixedSessionTypes() {
    // Add mix of active and expired sessions beyond max capacity
    for i in 1 ... 40 {
      let session: AwsSession
      let eventType: SessionEventType
      if i % 3 == 0 {
        // Every third session is expired
        session = AwsSession(
          id: "session-\(i)",
          expireTime: Date().addingTimeInterval(-3600)
        )
        eventType = .end
      } else {
        session = AwsSession(
          id: "session-\(i)",
          expireTime: Date().addingTimeInterval(3600)
        )
        eventType = .start
      }
      AwsSessionEventInstrumentation.addSession(session: session, eventType: eventType)
    }

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 32)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.first?.session.id, "session-1")
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.last?.session.id, "session-32")
  }

  func testQueueDoesNotEnforceMaxSizeAfterInstrumentationApplied() {
    _ = AwsSessionEventInstrumentation()
    let max: UInt8 = AwsSessionEventInstrumentation.maxQueueSize + 1

    // Add sessions after instrumentation is applied
    for i in 1 ... max {
      let session = AwsSession(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      AwsSessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    // Queue should remain empty as sessions are processed via notifications
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)

    // All sessions should be processed
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, Int(max))
  }

  func testProcessingQueuedSessionsAfterMaxSizeEnforcement() {
    // Add sessions beyond max capacity
    for i in 1 ... 40 {
      let session = AwsSession(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      AwsSessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 32)

    // Apply instrumentation to process queued sessions
    _ = AwsSessionEventInstrumentation()

    // Only the first 32 sessions should be processed (sessions 33-40 were dropped)
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 32)

    // Verify the first processed session is session-1 (first added)
    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string("session-1"))
    // Verify the last processed session is session-32 (last one that fit in queue)
    XCTAssertEqual(logRecords[31].attributes["session.id"], AttributeValue.string("session-32"))
  }

  // MARK: - SessionManager Integration Tests

  func testSessionManagerTenSessionChain() {
    _ = AwsSessionEventInstrumentation()
    let sessionManager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: 0))

    var sessions: [AwsSession] = []

    // Create 10 sessions in sequence
    for _ in 1 ... 10 {
      sessions.append(sessionManager.getSession())
    }

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 19) // 1 start + 9*(end+start) = 1 + 18 = 19

    // Verify first session has no previous ID
    let firstStartRecord = logRecords.first { record in
      record.body == AttributeValue.string("session.start") &&
        record.attributes["session.id"] == AttributeValue.string(sessions[0].id)
    }
    XCTAssertNotNil(firstStartRecord)
    XCTAssertNil(firstStartRecord!.attributes["session.previous_id"])

    // Verify session chain linking
    for i in 1 ..< sessions.count {
      let sessionStartRecord = logRecords.first { record in
        record.body == AttributeValue.string("session.start") &&
          record.attributes["session.id"] == AttributeValue.string(sessions[i].id)
      }
      XCTAssertNotNil(sessionStartRecord)
      XCTAssertEqual(sessionStartRecord?.attributes["session.previous_id"], AttributeValue.string(sessions[i - 1].id))
    }
  }

  // MARK: - Explicit Event Type Tests

  func testAddSessionWithExplicitStartEventType() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionId1))
  }

  func testAddSessionWithExplicitEndEventType() {
    let sessionWithEndTime = AwsSession(
      id: sessionIdExpired,
      expireTime: Date().addingTimeInterval(-3600),
      startTime: Date().addingTimeInterval(-7200)
    )

    AwsSessionEventInstrumentation.addSession(session: sessionWithEndTime, eventType: .end)
    _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.end"))
    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionIdExpired))
  }

  func testQueueStoresEventType() {
    AwsSessionEventInstrumentation.addSession(session: session1, eventType: .start)
    AwsSessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 2)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue[0].eventType, .start)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue[1].eventType, .end)
  }
}
