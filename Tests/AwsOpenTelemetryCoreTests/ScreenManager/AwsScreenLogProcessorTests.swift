import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk
@testable import TestUtils

final class AwsScreenLogProcessorTests: XCTestCase {
  var screenManager: AwsScreenManager!
  var mockNextProcessor: MockLogRecordProcessor!
  var logProcessor: AwsScreenLogRecordProcessor!
  var testLogRecord: ReadableLogRecord!

  override func setUp() {
    super.setUp()
    screenManager = AwsScreenManager()
    mockNextProcessor = MockLogRecordProcessor()
    logProcessor = AwsScreenLogRecordProcessor(nextProcessor: mockNextProcessor, screenManager: screenManager)
    testLogRecord = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: [:]
    )
  }

  func testOnEmitAddsScreenName() {
    screenManager.setCurrent(screen: "HomeScreen")

    logProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.processedLogRecords.count, 1)
    let processedRecord = mockNextProcessor.processedLogRecords[0]
    XCTAssertEqual(processedRecord.attributes[AwsView.screenName], AttributeValue.string("HomeScreen"))
  }

  func testOnEmitWithNilScreenName() {
    logProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.processedLogRecords.count, 1)
    let processedRecord = mockNextProcessor.processedLogRecords[0]
    XCTAssertNil(processedRecord.attributes[AwsView.screenName])
  }

  func testOnEmitDoesNotOverrideExistingScreenName() {
    screenManager.setCurrent(screen: "HomeScreen")
    let recordWithExistingScreenName = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: [AwsView.screenName: AttributeValue.string("ExistingScreen")]
    )

    logProcessor.onEmit(logRecord: recordWithExistingScreenName)

    XCTAssertEqual(mockNextProcessor.processedLogRecords.count, 1)
    let processedRecord = mockNextProcessor.processedLogRecords[0]
    XCTAssertEqual(processedRecord.attributes[AwsView.screenName], AttributeValue.string("ExistingScreen"))
  }

  func testShutdownReturnsSuccess() {
    let result = logProcessor.shutdown(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testForceFlushReturnsSuccess() {
    let result = logProcessor.forceFlush(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testInitializationWithNilScreenManager() {
    let processor = AwsScreenLogRecordProcessor(nextProcessor: mockNextProcessor, screenManager: nil)
    XCTAssertNotNil(processor)
  }
}
