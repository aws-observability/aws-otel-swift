import XCTest
@testable import AwsOpenTelemetryCore
@testable import TestUtils
import OpenTelemetryApi
import OpenTelemetrySdk

class MockStackTraceCollector: StackTraceCollector {
  var maxStackTraceLength: Int
  var shouldReturnStackTrace: Bool = true
  var mockStackTraceData: Data = "mock stack trace data".data(using: .utf8)!
  var mockStackTrace: StackTrace = .init(
    message: "Hang detected on main thread at MockFunction",
    stacktrace: "Thread 0:\n0 MockFunction + 123\n1 AnotherFunction + 456"
  )

  required init(maxStackTraceLength: Int = 10000) {
    self.maxStackTraceLength = maxStackTraceLength
  }

  func generateLiveStackTrace() -> Data? {
    return shouldReturnStackTrace ? mockStackTraceData : nil
  }

  func formatStackTrace(rawStackTrace: Data) -> StackTrace {
    return mockStackTrace
  }
}

final class AwsHangInstrumentationTests: XCTestCase {
  var mockStackTraceCollector: MockStackTraceCollector!
  var spanExporter: InMemorySpanExporter!
  var instrumentation: AwsHangInstrumentation!

  override func setUp() {
    super.setUp()
    mockStackTraceCollector = MockStackTraceCollector()
    spanExporter = InMemorySpanExporter.register()
    instrumentation = AwsHangInstrumentation(stackTraceCollector: mockStackTraceCollector)
  }

  override func tearDown() {
    spanExporter.clear()
    instrumentation = nil
    mockStackTraceCollector = nil
    spanExporter = nil
    super.tearDown()
  }

  func testInitialization() {
    XCTAssertEqual(instrumentation.hangThreshold, 0.25)
    XCTAssertEqual(instrumentation.hangPredetectionThreshold, 0.25 * 2 / 3)
    XCTAssertNotNil(instrumentation.stackTraceCollector)
    XCTAssertNil(instrumentation.hangStart)
    XCTAssertNil(instrumentation.rawStackTrace)
  }

  func testCheckForOngoingHangWithoutHangStart() {
    instrumentation.hangStart = nil
    instrumentation.checkForOngoingHang()
    XCTAssertNil(instrumentation.rawStackTrace)
  }

  func testCheckForOngoingHangWithExistingStackTrace() {
    let testTime = CFAbsoluteTimeGetCurrent()
    instrumentation.hangStart = testTime
    instrumentation.rawStackTrace = "existing".data(using: .utf8)!

    instrumentation.checkForOngoingHang()

    XCTAssertEqual(instrumentation.rawStackTrace, "existing".data(using: .utf8)!)
  }

  func testCheckForOngoingHangBelowThreshold() {
    let testTime = CFAbsoluteTimeGetCurrent() - 0.1
    instrumentation.hangStart = testTime
    instrumentation.rawStackTrace = nil

    instrumentation.checkForOngoingHang()

    XCTAssertNil(instrumentation.rawStackTrace)
  }

  func testCheckForOngoingHangAboveThreshold() {
    let testTime = CFAbsoluteTimeGetCurrent() - 0.2
    instrumentation.hangStart = testTime
    instrumentation.rawStackTrace = nil
    mockStackTraceCollector.shouldReturnStackTrace = true

    instrumentation.checkForOngoingHang()

    XCTAssertNotNil(instrumentation.rawStackTrace)
    XCTAssertEqual(instrumentation.rawStackTrace, mockStackTraceCollector.mockStackTraceData)
  }

  func testReportHangWithStackTrace() {
    let startTime: CFAbsoluteTime = 12345.0
    let endTime: CFAbsoluteTime = 12345.5
    let testStackTrace = "test stack trace".data(using: .utf8)!

    instrumentation.rawStackTrace = testStackTrace
    instrumentation.reportHang(startTime: startTime, endTime: endTime)

    let expectation = XCTestExpectation(description: "Span creation")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    XCTAssertEqual(spanExporter.getExportedSpans().count, 1)

    let span = spanExporter.getExportedSpans().first!
    XCTAssertEqual(span.name, "device.hang")
    XCTAssertEqual(span.attributes["exception.type"]?.description, "hang")
    XCTAssertEqual(span.attributes["exception.message"]?.description, mockStackTraceCollector.mockStackTrace.message)
    XCTAssertEqual(span.attributes["exception.stacktrace"]?.description, mockStackTraceCollector.mockStackTrace.stacktrace)
  }

  func testReportHangWithoutStackTrace() {
    let startTime: CFAbsoluteTime = 12345.0
    let endTime: CFAbsoluteTime = 12345.5

    instrumentation.rawStackTrace = nil
    instrumentation.reportHang(startTime: startTime, endTime: endTime)

    let expectation = XCTestExpectation(description: "Span creation")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    XCTAssertEqual(spanExporter.getExportedSpans().count, 1)

    let span = spanExporter.getExportedSpans().first!
    XCTAssertEqual(span.name, "device.hang")
    XCTAssertEqual(span.attributes["exception.type"]?.description, "hang")
    XCTAssertEqual(span.attributes["exception.message"]?.description, "Hang detected at unknown location")
    XCTAssertEqual(span.attributes["exception.stacktrace"]?.description, "No stack trace captured")
  }

  func testSharedInstance() {
    let shared1 = AwsHangInstrumentation.shared
    let shared2 = AwsHangInstrumentation.shared

    XCTAssertTrue(shared1 === shared2)
  }

  func testQueueConfiguration() {
    XCTAssertNotNil(instrumentation.syncQueue)
    XCTAssertNotNil(instrumentation.watchdogQueue)

    let syncQueueLabel = instrumentation.syncQueue.label
    let watchdogQueueLabel = instrumentation.watchdogQueue.label

    XCTAssertTrue(syncQueueLabel.contains(AwsInstrumentationScopes.HANG))
    XCTAssertEqual(watchdogQueueLabel, AwsInstrumentationScopes.HANG)
  }
}
