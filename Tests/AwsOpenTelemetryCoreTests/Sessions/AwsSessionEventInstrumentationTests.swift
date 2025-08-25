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

    OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
  }

  func testQueueInitiallyEmpty() {
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)
    XCTAssertFalse(AwsSessionEventInstrumentation.isApplied)
  }

  func testHandleNewSessionAddsToQueue() {
    AwsSessionEventInstrumentation.addSession(session: session1)

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue[0].id, sessionId1)
  }

  func testInstrumentationEmptiesQueue() {
    AwsSessionEventInstrumentation.addSession(session: session1)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1)
    AwsSessionEventInstrumentation.addSession(session: session2)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 2)
    XCTAssertFalse(AwsSessionEventInstrumentation.isApplied)

    let _ = AwsSessionEventInstrumentation()

    XCTAssertTrue(AwsSessionEventInstrumentation.isApplied)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)
  }

  func testQueueDoesNotFillAfterApplied() {
    let _ = AwsSessionEventInstrumentation()

    AwsSessionEventInstrumentation.addSession(session: session2)

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)
  }

  func testNotificationPostedAfterInstrumentationApplied() {
    let expectation = XCTestExpectation(description: "Session notification posted")
    var receivedSession: AwsSession?

    NotificationCenter.default.addObserver(
      forName: AwsSessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedSession = notification.object as? AwsSession
      expectation.fulfill()
    }

    let _ = AwsSessionEventInstrumentation()

    AwsSessionEventInstrumentation.addSession(session: session1)

    wait(for: [expectation], timeout: 0)

    XCTAssertNotNil(receivedSession)
    XCTAssertEqual(receivedSession?.id, sessionId1)
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

    AwsSessionEventInstrumentation.addSession(session: session1)

    wait(for: [expectation], timeout: 0.1)

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1)
  }

  func testMultipleInitializationDoesNotProcessQueueTwice() {
    AwsSessionEventInstrumentation.addSession(session: session1)
    AwsSessionEventInstrumentation.addSession(session: session2)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 2)

    let _ = AwsSessionEventInstrumentation()
    XCTAssertTrue(AwsSessionEventInstrumentation.isApplied)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)

    // Second initialization should not process queue again
    AwsSessionEventInstrumentation.queue = [sessionExpired]
    let _ = AwsSessionEventInstrumentation()
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 1) // Queue unchanged
  }

  func testMultipleInitializationDoesNotAddDuplicateObservers() {
    let _ = AwsSessionEventInstrumentation()
    let _ = AwsSessionEventInstrumentation()

    AwsSessionEventInstrumentation.addSession(session: session1)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
  }

  func testSessionStartLogRecord() {
    AwsSessionEventInstrumentation.addSession(session: session1)
    let _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(startTime1.timeIntervalSince1970))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testSessionStartApplyAfter() {
    AwsSessionEventInstrumentation.addSession(session: session1)
    let _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(session1.startTime.timeIntervalSince1970))
    XCTAssertNil(record.attributes["session.previous_id"])
    XCTAssertNil(record.attributes["session.end_time"])
    XCTAssertNil(record.attributes["session.duration"])
  }

  func testSessionStartApplyBefore() {
    let _ = AwsSessionEventInstrumentation()
    AwsSessionEventInstrumentation.addSession(session: session1)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(session1.startTime.timeIntervalSince1970))
    XCTAssertNil(record.attributes["session.previous_id"])
    XCTAssertNil(record.attributes["session.end_time"])
    XCTAssertNil(record.attributes["session.duration"])
  }

  func testSessionEndApplyBefore() {
    let _ = AwsSessionEventInstrumentation()
    AwsSessionEventInstrumentation.addSession(session: sessionExpired)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.end"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(sessionExpired.startTime.timeIntervalSince1970))
    XCTAssertNil(record.attributes["session.previous_id"])
    XCTAssertEqual(record.attributes["session.end_time"], AttributeValue.double(sessionExpired.endTime!.timeIntervalSince1970))
    XCTAssertEqual(record.attributes["session.duration"], AttributeValue.double(sessionExpired.duration!))
  }

  func testSessionEndApplyAfter() {
    AwsSessionEventInstrumentation.addSession(session: sessionExpired)
    let _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.end"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(sessionExpired.startTime.timeIntervalSince1970))
    XCTAssertNil(record.attributes["session.previous_id"])
    XCTAssertEqual(record.attributes["session.end_time"], AttributeValue.double(sessionExpired.endTime!.timeIntervalSince1970))
    XCTAssertEqual(record.attributes["session.duration"], AttributeValue.double(sessionExpired.duration!))
  }

  func testSessionStartLogRecordWithPreviousId() {
    AwsSessionEventInstrumentation.addSession(session: session2)
    let _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(startTime2.timeIntervalSince1970))
    XCTAssertEqual(record.attributes["session.previous_id"], AttributeValue.string(sessionId1))
  }

  func testSessionEndLogRecord() {
    AwsSessionEventInstrumentation.addSession(session: sessionExpired)
    let _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.end"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(sessionExpired.startTime.timeIntervalSince1970))
    XCTAssertEqual(record.attributes["session.end_time"], AttributeValue.double(sessionExpired.endTime!.timeIntervalSince1970))
    XCTAssertEqual(record.attributes["session.duration"], AttributeValue.double(sessionExpired.duration!))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testInstrumentationScopeName() {
    AwsSessionEventInstrumentation.addSession(session: session1)
    let _ = AwsSessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(AwsSessionEventInstrumentation.instrumentationKey, "aws-otel-swift.session")
    XCTAssertEqual(logRecords.first?.instrumentationScopeInfo.name, "aws-otel-swift.session")
  }

  func testMultipleSessionsProcessedInOrderAfterinstrumentation() {
    AwsSessionEventInstrumentation.addSession(session: session1)
    AwsSessionEventInstrumentation.addSession(session: session2)
    AwsSessionEventInstrumentation.addSession(session: sessionExpired)

    let _ = AwsSessionEventInstrumentation()

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
    let _ = AwsSessionEventInstrumentation()

    AwsSessionEventInstrumentation.addSession(session: session1)
    AwsSessionEventInstrumentation.addSession(session: session2)
    AwsSessionEventInstrumentation.addSession(session: sessionExpired)

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
    XCTAssertEqual(AwsSessionEventInstrumentation.maxQueueSize, 20)
  }

  func testQueueEnforcesMaxSize() {
    // Add sessions up to max capacity
    for i in 1 ... 20 {
      let session = AwsSession(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      AwsSessionEventInstrumentation.addSession(session: session)
    }

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 20)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.first?.id, "session-1")
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.last?.id, "session-20")
  }

  func testQueueDropsNewEventsWhenExceedingMaxSize() {
    // Add sessions beyond max capacity
    for i in 1 ... 25 {
      let session = AwsSession(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      AwsSessionEventInstrumentation.addSession(session: session)
    }

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 20)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.first?.id, "session-1")
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.last?.id, "session-20")
  }

  func testMaxQueueSizeWithMixedSessionTypes() {
    // Add mix of active and expired sessions beyond max capacity
    for i in 1 ... 25 {
      let session: AwsSession
      if i % 3 == 0 {
        // Every third session is expired
        session = AwsSession(
          id: "session-\(i)",
          expireTime: Date().addingTimeInterval(-3600)
        )
      } else {
        session = AwsSession(
          id: "session-\(i)",
          expireTime: Date().addingTimeInterval(3600)
        )
      }
      AwsSessionEventInstrumentation.addSession(session: session)
    }

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 20)
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.first?.id, "session-1")
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.last?.id, "session-20")
  }

  func testQueueDoesNotEnforceMaxSizeAfterInstrumentationApplied() {
    let _ = AwsSessionEventInstrumentation()

    // Add sessions after instrumentation is applied
    for i in 1 ... 15 {
      let session = AwsSession(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      AwsSessionEventInstrumentation.addSession(session: session)
    }

    // Queue should remain empty as sessions are processed via notifications
    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 0)

    // All sessions should be processed
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 15)
  }

  func testProcessingQueuedSessionsAfterMaxSizeEnforcement() {
    // Add sessions beyond max capacity
    for i in 1 ... 25 {
      let session = AwsSession(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      AwsSessionEventInstrumentation.addSession(session: session)
    }

    XCTAssertEqual(AwsSessionEventInstrumentation.queue.count, 20)

    // Apply instrumentation to process queued sessions
    let _ = AwsSessionEventInstrumentation()

    // Only the first 20 sessions should be processed (sessions 21-25 were dropped)
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 20)

    // Verify the first processed session is session-1 (first added)
    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string("session-1"))
    // Verify the last processed session is session-20 (last one that fit in queue)
    XCTAssertEqual(logRecords[19].attributes["session.id"], AttributeValue.string("session-20"))
  }
}
