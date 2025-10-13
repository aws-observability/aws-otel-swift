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
      XCTAssertEqual(log.eventName, "device.crash")
      XCTAssertEqual(log.instrumentationScopeInfo.name, "software.amazon.opentelemetry.MXCrashDiagnostic")
      XCTAssertNotNil(log.observedTimestamp, "Observed timestamp should be set")
      XCTAssertEqual(log.attributes["crash.exception_type"]?.description, "1")
      XCTAssertEqual(log.attributes["crash.exception_code"]?.description, "2")
      XCTAssertEqual(log.attributes["crash.signal"]?.description, "11")
      XCTAssertEqual(log.attributes["crash.termination_reason"]?.description, "test termination")
      XCTAssertEqual(log.attributes["crash.vm_region.info"]?.description, "test vm info")
      XCTAssertNotNil(log.attributes["crash.stacktrace"])
      XCTAssertTrue(log.attributes["crash.stacktrace"]?.description.contains("callStacks") == true)
    }

    func testBuildCrashAttributesWithMockCrash() {
      let mockCrash = MockMXCrashDiagnostic()
      let attributes = AwsMetricKitCrashProcessor.buildCrashAttributes(from: mockCrash)

      XCTAssertEqual(attributes["crash.exception_type"]?.description, "1")
      XCTAssertEqual(attributes["crash.exception_code"]?.description, "2")
      XCTAssertEqual(attributes["crash.signal"]?.description, "11")
      XCTAssertEqual(attributes["crash.termination_reason"]?.description, "test termination")
      XCTAssertEqual(attributes["crash.vm_region.info"]?.description, "test vm info")
      XCTAssertNotNil(attributes["crash.stacktrace"])
      XCTAssertTrue(attributes["crash.stacktrace"]?.description.contains("callStacks") == true)
    }

    func testObservedTimestampIsSetOnCrashLog() {
      let beforeTime = Date()
      let mockCrash = MockMXCrashDiagnostic()
      AwsMetricKitCrashProcessor.processCrashDiagnostics([mockCrash])
      let afterTime = Date()

      let logs = logExporter.getExportedLogs()
      XCTAssertEqual(logs.count, 1)

      let log = logs[0]
      XCTAssertNotNil(log.observedTimestamp)

      // Verify the observed timestamp is within a reasonable range
      let observedTime = log.observedTimestamp!
      XCTAssertGreaterThanOrEqual(observedTime, beforeTime)
      XCTAssertLessThanOrEqual(observedTime, afterTime)
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
      let jsonString = """
      {
        "callStackPerThread": true,
        "callStacks": [
          {
            "callStackRootFrames": [
              {
                "address": 4371867052,
                "offsetIntoBinaryTextSegment": 124332,
                "binaryUUID": "C42F630F-A71A-3EDC-9225-CF2C231A6669",
                "binaryName": "TestApp",
                "sampleCount": 1
              }
            ],
            "threadAttributed": true
          }
        ]
      }
      """
      return Data(jsonString.utf8)
    }
  }
#endif
