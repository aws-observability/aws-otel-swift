import XCTest
@testable import AwsOpenTelemetryCore
#if !os(watchOS)
  import CrashReporter
#endif

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

#if !os(watchOS)

  // MARK: - PLStackTraceReporterTests Tests

  final class PLLiveStackTraceReporterTests: XCTestCase {
    var collector: PLLiveStackTraceReporter!

    override func setUp() {
      super.setUp()
      collector = PLLiveStackTraceReporter(maxStackTraceLength: 1000)
    }

    override func tearDown() {
      collector = nil
      super.tearDown()
    }

    func testInitialization() {
      XCTAssertEqual(collector.maxStackTraceLength, 1000)
      XCTAssertNotNil(collector.reporter)
    }

    func testDefaultInitialization() {
      let defaultCollector = PLLiveStackTraceReporter()
      XCTAssertEqual(defaultCollector.maxStackTraceLength, 10000)
    }

    func testGenerateLiveStackTrace() {
      XCTAssertNoThrow(collector.generateLiveStackTrace())
    }

    func testFormatStackTraceWithInvalidData() {
      let invalidData = "invalid crash report data".data(using: .utf8)!
      let result = collector.formatStackTrace(rawStackTrace: invalidData)

      XCTAssertEqual(result.message, "Hang detected on main thread at unknown location")
      XCTAssertTrue(result.stacktrace.contains("Failed to parse stack trace"))
    }

    func testFormatStackTraceWithEmptyData() {
      let emptyData = Data()
      let result = collector.formatStackTrace(rawStackTrace: emptyData)

      XCTAssertEqual(result.message, "Hang detected on main thread at unknown location")
      XCTAssertTrue(result.stacktrace.contains("Failed to parse stack trace"))
    }

    func testMaxStackTraceLengthTruncation() {
      let shortCollector = PLLiveStackTraceReporter(maxStackTraceLength: 10)
      let longData = String(repeating: "a", count: 1000).data(using: .utf8)!
      let result = shortCollector.formatStackTrace(rawStackTrace: longData)

      XCTAssertTrue(result.stacktrace.count <= 1000)
    }

    func testGetFirstFrameOfMainWithValidStacktrace() {
      let stacktrace = """
      Thread 0:
      0   MyApp                           0x0000000100001234 main + 52
      1   libdyld.dylib                   0x00007fff12345678 start + 1
      """

      let result = collector.getFirstFrameOfMain(stacktrace: stacktrace)
      XCTAssertEqual(result, "MyApp 0x0000000100001234 main + 52")
    }

    func testGetFirstFrameOfMainWithComplexStacktrace() {
      let stacktrace = """
      Thread 0:
      0   MyApp                           0x0000000100001234 -[ViewController viewDidLoad] + 52 (ViewController.m:25)
      1   UIKitCore                       0x00007fff12345678 -[UIViewController loadViewIfRequired] + 1234
      """

      let result = collector.getFirstFrameOfMain(stacktrace: stacktrace)
      XCTAssertEqual(result, "MyApp 0x0000000100001234 -[ViewController viewDidLoad] + 52 (ViewController.m:25)")
    }

    func testGetFirstFrameOfMainWithWhitespaceHandling() {
      let stacktrace = """
      Thread 0:
      0    MyApp     0x0000000100001234    main    +    52   
      """

      let result = collector.getFirstFrameOfMain(stacktrace: stacktrace)
      XCTAssertEqual(result, "MyApp 0x0000000100001234 main + 52")
    }

    func testGetFirstFrameOfMainWithNoMainThread() {
      let stacktrace = "Some other thread info"
      let result = collector.getFirstFrameOfMain(stacktrace: stacktrace)
      XCTAssertNil(result)
    }

    func testGetFirstFrameOfMainWithEmptyStacktrace() {
      let stacktrace = ""
      let result = collector.getFirstFrameOfMain(stacktrace: stacktrace)
      XCTAssertNil(result)
    }

    func testGetFirstFrameOfMainWithMalformedStacktrace() {
      let stacktrace = "Thread 0:\n0"
      let result = collector.getFirstFrameOfMain(stacktrace: stacktrace)
      XCTAssertEqual(result, "")
    }

    func testFormatStackTraceWithNilReportString() {
      let malformedData = Data([0x00, 0x01, 0x02, 0x03])
      let result = collector.formatStackTrace(rawStackTrace: malformedData)

      XCTAssertEqual(result.message, "Hang detected on main thread at unknown location")
      XCTAssertTrue(result.stacktrace.contains("Failed to"))
    }
  }
#endif

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
  func testPLLiveStackTraceReporterConformsToProtocol() {
    #if !os(watchOS)
      let collector: LiveStackTraceReporter = PLLiveStackTraceReporter(maxStackTraceLength: 1000)
      XCTAssertEqual(collector.maxStackTraceLength, 1000)
      XCTAssertNoThrow(collector.generateLiveStackTrace())

      let data = Data()
      let result = collector.formatStackTrace(rawStackTrace: data)
      XCTAssertNotNil(result.message)
      XCTAssertNotNil(result.stacktrace)
    #endif
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
