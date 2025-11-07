import XCTest
import OpenTelemetrySdk
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import TestUtils

final class AwsSessionLogSamplerTests: XCTestCase {
  var mockSessionManager: MockLogSamplerSessionManager!
  var mockProcessor: MockLogSamplerProcessor!
  var sampler: AwsSessionLogSampler!

  override func setUp() {
    super.setUp()
    mockSessionManager = MockLogSamplerSessionManager()
    mockProcessor = MockLogSamplerProcessor()
    sampler = AwsSessionLogSampler(nextProcessor: mockProcessor, sessionManager: mockSessionManager)
  }

  func testOnEmitWithSampledSession() {
    mockSessionManager.setSessionSampled(true)
    let logRecord = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: [:]
    )

    sampler.onEmit(logRecord: logRecord)

    XCTAssertEqual(mockProcessor.emittedRecords.count, 1)
  }

  func testOnEmitWithUnsampledSession() {
    mockSessionManager.setSessionSampled(false)
    let logRecord = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: [:]
    )

    sampler.onEmit(logRecord: logRecord)

    XCTAssertEqual(mockProcessor.emittedRecords.count, 0)
  }

  func testShutdownDelegatesToNextProcessor() {
    let result = sampler.shutdown(explicitTimeout: 5.0)

    XCTAssertEqual(result, .success)
    XCTAssertTrue(mockProcessor.shutdownCalled)
    XCTAssertEqual(mockProcessor.shutdownTimeout, 5.0)
  }

  func testForceFlushDelegatesToNextProcessor() {
    let result = sampler.forceFlush(explicitTimeout: 3.0)

    XCTAssertEqual(result, .success)
    XCTAssertTrue(mockProcessor.forceFlushCalled)
    XCTAssertEqual(mockProcessor.forceFlushTimeout, 3.0)
  }
}

// MARK: - Mock Classes

class MockLogSamplerSessionManager: AwsSessionManager {
  private var _isSessionSampled: Bool = true

  override var isSessionSampled: Bool {
    return _isSessionSampled
  }

  func setSessionSampled(_ sampled: Bool) {
    _isSessionSampled = sampled
  }

  override init(configuration: AwsSessionConfig = .default) {
    super.init(configuration: configuration)
  }
}

class MockLogSamplerProcessor: LogRecordProcessor {
  var emittedRecords: [ReadableLogRecord] = []
  var shutdownCalled = false
  var shutdownTimeout: TimeInterval?
  var forceFlushCalled = false
  var forceFlushTimeout: TimeInterval?

  func onEmit(logRecord: ReadableLogRecord) {
    emittedRecords.append(logRecord)
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    shutdownCalled = true
    shutdownTimeout = explicitTimeout
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    forceFlushCalled = true
    forceFlushTimeout = explicitTimeout
    return .success
  }
}
