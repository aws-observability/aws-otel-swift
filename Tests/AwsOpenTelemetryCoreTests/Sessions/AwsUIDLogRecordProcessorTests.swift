import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk
@testable import TestUtils

final class AwsUIDLogRecordProcessorTests: XCTestCase {
  var uidManager: AwsUIDManager!
  var mockNextProcessor: MockLogRecordProcessor!
  var logRecordProcessor: AwsUIDLogRecordProcessor!
  var testLogRecord: ReadableLogRecord!

  override func setUp() {
    super.setUp()
    // Clear any existing UID for clean tests
    UserDefaults.standard.removeObject(forKey: "aws-rum-user-id")
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
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 1)
    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    XCTAssertTrue(enhancedRecord.attributes.keys.contains("user.id"))
    if case .string = enhancedRecord.attributes["user.id"] {
      // UID exists and is a string - test passes
    } else {
      XCTFail("Expected user.id attribute to be a string value")
    }
  }

  func testOnEmitPreservesOriginalAttributes() {
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
    // Set first UID in UserDefaults
    UserDefaults.standard.set("uid-1", forKey: "aws-rum-user-id")
    let uidManager1 = AwsUIDManager()
    let processor1 = AwsUIDLogRecordProcessor(nextProcessor: mockNextProcessor, uidManager: uidManager1)
    processor1.onEmit(logRecord: testLogRecord)

    // Set second UID in UserDefaults
    UserDefaults.standard.set("uid-2", forKey: "aws-rum-user-id")
    let uidManager2 = AwsUIDManager()
    let processor2 = AwsUIDLogRecordProcessor(nextProcessor: mockNextProcessor, uidManager: uidManager2)
    processor2.onEmit(logRecord: testLogRecord)

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

    for _ in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        self.logRecordProcessor.onEmit(logRecord: self.testLogRecord)
        group.leave()
      }
    }

    group.wait()

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 100)
    for record in mockNextProcessor.receivedLogRecords {
      XCTAssertTrue(record.attributes.keys.contains("user.id"))
    }
  }
}
