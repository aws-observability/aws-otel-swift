import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsSessionLogRecordProcessorTests: XCTestCase {
  var mockSessionManager: MockSessionManager!
  var mockNextProcessor: MockLogRecordProcessor!
  var logRecordProcessor: AwsSessionLogRecordProcessor!
  var testLogRecord: ReadableLogRecord!

  override func setUp() {
    super.setUp()
    mockSessionManager = MockSessionManager()
    mockNextProcessor = MockLogRecordProcessor()
    logRecordProcessor = AwsSessionLogRecordProcessor(nextProcessor: mockNextProcessor, sessionManager: mockSessionManager)

    testLogRecord = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: ["original.key": AttributeValue.string("original.value")]
    )
  }

  func testOnEmitAddsSessionAttributes() {
    let expectedSessionId = "test-session-123"
    mockSessionManager.sessionId = expectedSessionId

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 1)
    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[AwsSessionConstants.id] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }
  }

  func testOnEmitPreservesOriginalAttributes() {
    mockSessionManager.sessionId = "test-session"

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(originalValue) = enhancedRecord.attributes["original.key"] {
      XCTAssertEqual(originalValue, "original.value")
    } else {
      XCTFail("Expected original.key attribute to be preserved")
    }

    XCTAssertEqual(enhancedRecord.resource.attributes, testLogRecord.resource.attributes)
    XCTAssertEqual(enhancedRecord.instrumentationScopeInfo.name, testLogRecord.instrumentationScopeInfo.name)
    XCTAssertEqual(enhancedRecord.timestamp, testLogRecord.timestamp)
    XCTAssertEqual(enhancedRecord.observedTimestamp, testLogRecord.observedTimestamp)
    XCTAssertEqual(enhancedRecord.severity, testLogRecord.severity)
    XCTAssertEqual(enhancedRecord.body?.description, testLogRecord.body?.description)
    XCTAssertEqual(enhancedRecord.spanContext, testLogRecord.spanContext)
  }

  func testOnEmitAddsPreviousSessionId() {
    let expectedSessionId = "current-session-123"
    let expectedPreviousSessionId = "previous-session-456"
    mockSessionManager.sessionId = expectedSessionId
    mockSessionManager.previousSessionId = expectedPreviousSessionId

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[AwsSessionConstants.id] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }

    if case let .string(previousSessionId) = enhancedRecord.attributes[AwsSessionConstants.previousId] {
      XCTAssertEqual(previousSessionId, expectedPreviousSessionId)
    } else {
      XCTFail("Expected session.previous_id attribute to be a string value")
    }
  }

  func testOnEmitWithoutPreviousSessionId() {
    let expectedSessionId = "current-session-123"
    mockSessionManager.sessionId = expectedSessionId
    mockSessionManager.previousSessionId = nil

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[AwsSessionConstants.id] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }

    XCTAssertNil(enhancedRecord.attributes[AwsSessionConstants.previousId], "Previous session ID should not be set when nil")
  }

  func testOnEmitWithDifferentSessionIds() {
    mockSessionManager.sessionId = "session-1"
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    mockSessionManager.sessionId = "session-2"
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 2)

    if case let .string(sessionId1) = mockNextProcessor.receivedLogRecords[0].attributes[AwsSessionConstants.id] {
      XCTAssertEqual(sessionId1, "session-1")
    } else {
      XCTFail("Expected first log record to have session-1")
    }

    if case let .string(sessionId2) = mockNextProcessor.receivedLogRecords[1].attributes[AwsSessionConstants.id] {
      XCTAssertEqual(sessionId2, "session-2")
    } else {
      XCTFail("Expected second log record to have session-2")
    }
  }

  func testShutdownReturnsSuccess() {
    let result = logRecordProcessor.shutdown(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testForceFlushReturnsSuccess() {
    let result = logRecordProcessor.forceFlush(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testPreservesExistingSessionId() {
    let recordWithExistingSessionId = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: [
        AwsSessionConstants.id: AttributeValue.string("existing-session-123"),
        "other.key": AttributeValue.string("other.value")
      ]
    )

    mockSessionManager.sessionId = "current-session-999"
    mockSessionManager.previousSessionId = "previous-session-888"
    logRecordProcessor.onEmit(logRecord: recordWithExistingSessionId)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[AwsSessionConstants.id] {
      XCTAssertEqual(sessionId, "existing-session-123", "Should preserve existing session ID")
    } else {
      XCTFail("Expected existing session.id to be preserved")
    }

    // Should still add previous session ID if not present
    if case let .string(previousId) = enhancedRecord.attributes[AwsSessionConstants.previousId] {
      XCTAssertEqual(previousId, "previous-session-888", "Should add previous session ID when not present")
    } else {
      XCTFail("Expected session.previous_id to be added")
    }
  }

  func testPreservesExistingPreviousSessionId() {
    let recordWithExistingPreviousId = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: [
        AwsSessionConstants.previousId: AttributeValue.string("existing-previous-456")
      ]
    )

    mockSessionManager.sessionId = "current-session-999"
    mockSessionManager.previousSessionId = "previous-session-888"
    logRecordProcessor.onEmit(logRecord: recordWithExistingPreviousId)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    // Should add session ID when not present
    if case let .string(sessionId) = enhancedRecord.attributes[AwsSessionConstants.id] {
      XCTAssertEqual(sessionId, "current-session-999", "Should add current session ID when not present")
    } else {
      XCTFail("Expected session.id to be added")
    }

    if case let .string(previousId) = enhancedRecord.attributes[AwsSessionConstants.previousId] {
      XCTAssertEqual(previousId, "existing-previous-456", "Should preserve existing previous session ID")
    } else {
      XCTFail("Expected existing session.previous_id to be preserved")
    }
  }

  func testPreservesBothExistingSessionAttributes() {
    let recordWithBothExisting = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: [
        AwsSessionConstants.id: AttributeValue.string("existing-session-123"),
        AwsSessionConstants.previousId: AttributeValue.string("existing-previous-456")
      ]
    )

    mockSessionManager.sessionId = "current-session-999"
    mockSessionManager.previousSessionId = "previous-session-888"
    logRecordProcessor.onEmit(logRecord: recordWithBothExisting)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[AwsSessionConstants.id] {
      XCTAssertEqual(sessionId, "existing-session-123", "Should preserve existing session ID")
    } else {
      XCTFail("Expected existing session.id to be preserved")
    }

    if case let .string(previousId) = enhancedRecord.attributes[AwsSessionConstants.previousId] {
      XCTAssertEqual(previousId, "existing-previous-456", "Should preserve existing previous session ID")
    } else {
      XCTFail("Expected existing session.previous_id to be preserved")
    }
  }

  func testConcurrentOnEmitThreadSafety() {
    let group = DispatchGroup()
    let syncQueue = DispatchQueue(label: "test.sync")

    for i in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        self.mockSessionManager.sessionId = "session-\(i)"
        self.logRecordProcessor.onEmit(logRecord: self.testLogRecord)
        group.leave()
      }
    }

    group.wait()

    syncQueue.sync {
      XCTAssertEqual(self.mockNextProcessor.receivedLogRecords.count, 100)
      for record in self.mockNextProcessor.receivedLogRecords {
        XCTAssertTrue(record.attributes.keys.contains(AwsSessionConstants.id))
      }
    }
  }
}
