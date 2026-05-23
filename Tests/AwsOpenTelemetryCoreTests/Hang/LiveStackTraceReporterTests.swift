import XCTest
@testable import AwsOpenTelemetryCore

// MARK: - NoopLiveStackTraceReporter Tests

final class NoopLiveStackTraceReporterTests: XCTestCase {
  func testInitialization() {
    let collector = NoopLiveStackTraceReporter(maxStackTraceLength: 5000)
    XCTAssertEqual(collector.maxStackTraceLength, 5000)
  }

  func testDefaultInitialization() {
    let collector = NoopLiveStackTraceReporter()
    XCTAssertEqual(collector.maxStackTraceLength, 10000)
  }

  func testGenerateLiveStackTrace() {
    let collector = NoopLiveStackTraceReporter()
    XCTAssertNil(collector.generateLiveStackTrace())
  }

  func testFormatStackTrace() {
    let collector = NoopLiveStackTraceReporter()
    let data = Data()

    let result = collector.formatStackTrace(rawStackTrace: data)

    XCTAssertEqual(result.message, "Stack trace collection not available")
    XCTAssertEqual(result.stacktrace, "Stack trace collection not supported on this platform")
  }

  func testFormatStackTraceWithData() {
    let collector = NoopLiveStackTraceReporter()
    let data = "some data".data(using: .utf8)!

    let result = collector.formatStackTrace(rawStackTrace: data)

    XCTAssertEqual(result.message, "Stack trace collection not available")
    XCTAssertEqual(result.stacktrace, "Stack trace collection not supported on this platform")
  }
}

// MARK: - KSCrashLiveStackTraceReporter Tests

final class KSCrashLiveStackTraceReporterTests: XCTestCase {
  var collector: KSCrashLiveStackTraceReporter!

  override func setUp() {
    super.setUp()
    collector = KSCrashLiveStackTraceReporter(maxStackTraceLength: 1000)
  }

  override func tearDown() {
    collector = nil
    super.tearDown()
  }

  func testInitialization() {
    XCTAssertEqual(collector.maxStackTraceLength, 1000)
  }

  func testDefaultInitialization() {
    let defaultCollector = KSCrashLiveStackTraceReporter()
    XCTAssertEqual(defaultCollector.maxStackTraceLength, 10000)
  }

  func testGenerateLiveStackTrace() {
    XCTAssertNoThrow(collector.generateLiveStackTrace())
  }

  func testFormatStackTraceWithInvalidData() {
    let invalidData = "invalid data".data(using: .utf8)!
    let result = collector.formatStackTrace(rawStackTrace: invalidData)

    XCTAssertEqual(result.message, "Hang detected at unknown location")
    XCTAssertEqual(result.stacktrace, "Failed to parse stack trace")
  }

  func testFormatStackTraceWithEmptyData() {
    let emptyData = Data()
    let result = collector.formatStackTrace(rawStackTrace: emptyData)

    XCTAssertEqual(result.message, "Hang detected at unknown location")
    XCTAssertEqual(result.stacktrace, "Failed to parse stack trace")
  }

  func testFormatStackTraceWithValidAddresses() {
    let addresses: [UInt] = [0x1000, 0x2000, 0x3000]
    let data = try! JSONEncoder().encode(addresses)
    let result = collector.formatStackTrace(rawStackTrace: data)

    XCTAssertTrue(result.stacktrace.hasPrefix("Thread 0:\n"))
    XCTAssertTrue(result.message.hasPrefix("Hang detected at"))
  }

  func testFormatStackTraceWithEmptyAddresses() {
    let addresses: [UInt] = []
    let data = try! JSONEncoder().encode(addresses)
    let result = collector.formatStackTrace(rawStackTrace: data)

    XCTAssertEqual(result.message, "Hang detected at unknown location")
    XCTAssertEqual(result.stacktrace, "Failed to parse stack trace")
  }

  func testMaxStackTraceLengthTruncation() {
    let shortCollector = KSCrashLiveStackTraceReporter(maxStackTraceLength: 20)
    let addresses: [UInt] = Array(repeating: 0x1000, count: 50)
    let data = try! JSONEncoder().encode(addresses)
    let result = shortCollector.formatStackTrace(rawStackTrace: data)

    XCTAssertTrue(result.stacktrace.count <= 20)
  }
}

// MARK: - StackTrace Struct Tests

final class StackTraceTests: XCTestCase {
  func testStackTraceStruct() {
    let stackTrace = StackTrace(message: "Test message", stacktrace: "Test stacktrace")
    XCTAssertEqual(stackTrace.message, "Test message")
    XCTAssertEqual(stackTrace.stacktrace, "Test stacktrace")
  }
}

// MARK: - Protocol Conformance Tests

final class LiveStackTraceReporterProtocolTests: XCTestCase {
  func testKSCrashLiveStackTraceReporterConformsToProtocol() {
    let collector: LiveStackTraceReporter = KSCrashLiveStackTraceReporter(maxStackTraceLength: 1000)
    XCTAssertEqual(collector.maxStackTraceLength, 1000)
    XCTAssertNoThrow(collector.generateLiveStackTrace())

    let data = Data()
    let result = collector.formatStackTrace(rawStackTrace: data)
    XCTAssertNotNil(result.message)
    XCTAssertNotNil(result.stacktrace)
  }

  func testNoopStackTraceCollectorConformsToProtocol() {
    let collector: LiveStackTraceReporter = NoopLiveStackTraceReporter(maxStackTraceLength: 2000)
    XCTAssertEqual(collector.maxStackTraceLength, 2000)
    XCTAssertNil(collector.generateLiveStackTrace())

    let data = Data()
    let result = collector.formatStackTrace(rawStackTrace: data)
    XCTAssertEqual(result.message, "Stack trace collection not available")
    XCTAssertEqual(result.stacktrace, "Stack trace collection not supported on this platform")
  }
}
