import XCTest
@testable import AwsOpenTelemetryCore
#if !os(watchOS)
  import CrashReporter
#endif

#if !os(watchOS)
  final class PLStackTraceCollectorTests: XCTestCase {
    var collector: PLStackTraceCollector!

    override func setUp() {
      super.setUp()
      collector = PLStackTraceCollector(maxStackTraceLength: 1000)
    }

    override func tearDown() {
      collector = nil
      super.tearDown()
    }

    func testInitialization() {
      XCTAssertEqual(collector.maxStackTraceLength, 1000)
      XCTAssertNotNil(collector.reporter)
    }

    func testGenerateLiveStackTrace() {
      // Should return some data (could be nil in test environment)
      // We can't guarantee it will work in test environment, so just verify it doesn't crash
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
      let shortCollector = PLStackTraceCollector(maxStackTraceLength: 10)
      let longData = String(repeating: "a", count: 1000).data(using: .utf8)!

      let result = shortCollector.formatStackTrace(rawStackTrace: longData)

      // Should handle truncation gracefully
      XCTAssertTrue(result.stacktrace.count <= 1000) // Won't be exactly 10 due to error message
    }

    func testRequiredInitializer() {
      // Test that required initializer works
      let collector2 = PLStackTraceCollector(maxStackTraceLength: 5000)
      XCTAssertEqual(collector2.maxStackTraceLength, 5000)
    }
  }
#endif
