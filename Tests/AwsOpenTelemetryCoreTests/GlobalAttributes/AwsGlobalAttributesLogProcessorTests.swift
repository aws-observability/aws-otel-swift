import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsGlobalAttributesLogProcessorTests: XCTestCase {
  var mockGlobalAttributesManager: LogProcessorMockGlobalAttributesManager!
  var mockNextProcessor: GlobalAttributesMockLogRecordProcessor!
  var logRecordProcessor: AwsGlobalAttributesLogProcessor!
  var testLogRecord: ReadableLogRecord!

  override func setUp() {
    super.setUp()
    mockGlobalAttributesManager = LogProcessorMockGlobalAttributesManager()
    mockNextProcessor = GlobalAttributesMockLogRecordProcessor()
    logRecordProcessor = AwsGlobalAttributesLogProcessor(nextProcessor: mockNextProcessor, globalAttributesManager: mockGlobalAttributesManager)

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

  func testOnEmitAddsGlobalAttributes() {
    mockGlobalAttributesManager.attributes = [
      "global.key1": AttributeValue.string("value1"),
      "global.key2": AttributeValue.int(42)
    ]

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 1)
    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    XCTAssertEqual(enhancedRecord.attributes["global.key1"], AttributeValue.string("value1"))
    XCTAssertEqual(enhancedRecord.attributes["global.key2"], AttributeValue.int(42))
  }

  func testOnEmitPreservesOriginalAttributes() {
    mockGlobalAttributesManager.attributes = ["global.key": AttributeValue.string("global.value")]

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    XCTAssertEqual(enhancedRecord.attributes["original.key"], AttributeValue.string("original.value"))
    XCTAssertEqual(enhancedRecord.attributes["global.key"], AttributeValue.string("global.value"))
  }

  func testOnEmitWithEmptyGlobalAttributes() {
    mockGlobalAttributesManager.attributes = [:]

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]
    XCTAssertEqual(enhancedRecord.attributes["original.key"], AttributeValue.string("original.value"))
    XCTAssertEqual(enhancedRecord.attributes.count, 1)
  }

  func testShutdownReturnsSuccess() {
    let result = logRecordProcessor.shutdown(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testForceFlushReturnsSuccess() {
    let result = logRecordProcessor.forceFlush(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testInitializationWithNilGlobalAttributesManager() {
    let processor = AwsGlobalAttributesLogProcessor(nextProcessor: mockNextProcessor, globalAttributesManager: nil)
    processor.onEmit(logRecord: testLogRecord)
    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 1)
  }
}

class LogProcessorMockGlobalAttributesManager: AwsGlobalAttributesManager {
  var attributes: [String: AttributeValue] = [:]

  override func getAttributes() -> [String: AttributeValue] {
    return attributes
  }
}

class GlobalAttributesMockLogRecordProcessor: LogRecordProcessor {
  var receivedLogRecords: [ReadableLogRecord] = []

  func onEmit(logRecord: ReadableLogRecord) {
    receivedLogRecords.append(logRecord)
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
