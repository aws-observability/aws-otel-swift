#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import XCTest
  import MetricKit
  import OpenTelemetryApi
  @testable import AwsOpenTelemetryCore
  @testable import TestUtils

  @available(iOS 15.0, *)
  final class AwsMetricKitCrashProcessorTests: XCTestCase {
    private var logExporter: InMemoryLogExporter!

    override func setUp() {
      super.setUp()
      logExporter = InMemoryLogExporter.register()
    }

    override func tearDown() {
      logExporter.clear()
      super.tearDown()
    }

    func testScopeName() {
      XCTAssertEqual(AwsMetricKitCrashProcessor.scopeName, "software.amazon.opentelemetry.MXCrashDiagnostic")
    }

    func testProcessCrashDiagnosticsWithNilDiagnostics() {
      AwsMetricKitCrashProcessor.processCrashDiagnostics(nil)
      XCTAssertEqual(logExporter.getExportedLogs().count, 0)
    }

    func testProcessCrashDiagnosticsWithEmptyDiagnostics() {
      AwsMetricKitCrashProcessor.processCrashDiagnostics([])
      XCTAssertEqual(logExporter.getExportedLogs().count, 0)
    }

    func testProcessCrashDiagnosticsWithMockCrash() {
      let mockCrash = MockMXCrashDiagnostic()
      AwsMetricKitCrashProcessor.processCrashDiagnostics([mockCrash])

      let logs = logExporter.getExportedLogs()
      XCTAssertEqual(logs.count, 1)

      let log = logs[0]
      XCTAssertEqual(log.body?.description, "crash")
      XCTAssertEqual(log.instrumentationScopeInfo.name, "software.amazon.opentelemetry.MXCrashDiagnostic")
      XCTAssertEqual(log.attributes["crash.exception_type"]?.description, "1")
      XCTAssertEqual(log.attributes["crash.exception_code"]?.description, "2")
      XCTAssertEqual(log.attributes["crash.signal"]?.description, "11")
      XCTAssertEqual(log.attributes["crash.termination_reason"]?.description, "test termination")
      XCTAssertEqual(log.attributes["crash.vm_region.info"]?.description, "test vm info")
      XCTAssertEqual(log.attributes["crash.stacktrace"]?.description, "{\"test\":\"stacktrace\"}")
    }

    func testBuildCrashAttributesWithMockCrash() {
      let mockCrash = MockMXCrashDiagnostic()
      let attributes = AwsMetricKitCrashProcessor.buildCrashAttributes(from: mockCrash)

      XCTAssertEqual(attributes["crash.exception_type"]?.description, "1")
      XCTAssertEqual(attributes["crash.exception_code"]?.description, "2")
      XCTAssertEqual(attributes["crash.signal"]?.description, "11")
      XCTAssertEqual(attributes["crash.termination_reason"]?.description, "test termination")
      XCTAssertEqual(attributes["crash.vm_region.info"]?.description, "test vm info")
      XCTAssertEqual(attributes["crash.stacktrace"]?.description, "{\"test\":\"stacktrace\"}")
    }
  }

  @available(iOS 15.0, *)
  private class MockMXCrashDiagnostic: MXCrashDiagnostic {
    override var exceptionType: NSNumber? { return NSNumber(value: 1) }
    override var exceptionCode: NSNumber? { return NSNumber(value: 2) }
    override var signal: NSNumber? { return NSNumber(value: 11) }
    override var terminationReason: String? { return "test termination" }
    override var virtualMemoryRegionInfo: String? { return "test vm info" }
    override var callStackTree: MXCallStackTree {
      return MockMXCallStackTree()
    }
  }

  @available(iOS 15.0, *)
  private class MockMXCallStackTree: MXCallStackTree {
    override func jsonRepresentation() -> Data {
      return Data("{\"test\":\"stacktrace\"}".utf8)
    }
  }
#endif
