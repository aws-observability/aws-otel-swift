import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsUIDLogRecordProcessorTests: XCTestCase {
  var uidManager: AwsUIDManager!
  var mockNextProcessor: MockLogRecordProcessor!
  var logRecordProcessor: AwsUIDLogRecordProcessor!
  var testLogRecord: ReadableLogRecord!

  override func setUp() {
    super.setUp()
    uidManager = AwsUIDManager()
    mockNextProcessor = MockLogRecordProcessor()
    logRecordProcessor = AwsUIDLogRecordProcessor(nextProcessor: mockNextProcessor, uidManager: uidManager)

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

  func testOnEmitAddsUIDAttribute() {
    let expectedUID = "test-uid-123"
    uidManager.uid = expectedUID

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 1)
    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(uid) = enhancedRecord.attributes["user.id"] {
      XCTAssertEqual(uid, expectedUID)
    } else {
      XCTFail("Expected user.id attribute to be a string value")
    }
  }

  func testOnEmitPreservesOriginalAttributes() {
    uidManager.uid = "test-uid"

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

  func testOnEmitWithDifferentUIDs() {
    uidManager.uid = "uid-1"
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    uidManager.uid = "uid-2"
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 2)

    if case let .string(uid1) = mockNextProcessor.receivedLogRecords[0].attributes["user.id"] {
      XCTAssertEqual(uid1, "uid-1")
    } else {
      XCTFail("Expected first log record to have uid-1")
    }

    if case let .string(uid2) = mockNextProcessor.receivedLogRecords[1].attributes["user.id"] {
      XCTAssertEqual(uid2, "uid-2")
    } else {
      XCTFail("Expected second log record to have uid-2")
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

  func testConcurrentOnEmitThreadSafety() {
    let group = DispatchGroup()
    let syncQueue = DispatchQueue(label: "test.sync")

    for i in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        self.uidManager.uid = "uid-\(i)"
        self.logRecordProcessor.onEmit(logRecord: self.testLogRecord)
        group.leave()
      }
    }

    group.wait()

    syncQueue.sync {
      XCTAssertEqual(self.mockNextProcessor.receivedLogRecords.count, 100)
      for record in self.mockNextProcessor.receivedLogRecords {
        XCTAssertTrue(record.attributes.keys.contains("user.id"))
      }
    }
  }
}

// MARK: - Mock Classes

class MockLogRecordProcessor: LogRecordProcessor {
  private let lock = NSLock()
  private var _receivedLogRecords: [ReadableLogRecord] = []

  var receivedLogRecords: [ReadableLogRecord] {
    return lock.withLock { _receivedLogRecords }
  }

  func onEmit(logRecord: ReadableLogRecord) {
    lock.withLock {
      _receivedLogRecords.append(logRecord)
    }
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
