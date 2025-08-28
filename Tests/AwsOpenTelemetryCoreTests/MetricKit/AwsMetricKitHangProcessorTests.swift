#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import XCTest
  import MetricKit
  import OpenTelemetryApi
  @testable import AwsOpenTelemetryCore
  @testable import TestUtils

  @available(iOS 15.0, *)
  final class AwsMetricKitHangProcessorTests: XCTestCase {
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
      XCTAssertEqual(AwsMetricKitHangProcessor.scopeName, "aws-otel-swift.MXHangDiagnostic")
    }

    func testProcessHangDiagnosticsWithNilDiagnostics() {
      AwsMetricKitHangProcessor.processHangDiagnostics(nil)
      XCTAssertEqual(logExporter.getExportedLogs().count, 0)
    }

    func testProcessHangDiagnosticsWithEmptyDiagnostics() {
      AwsMetricKitHangProcessor.processHangDiagnostics([])
      XCTAssertEqual(logExporter.getExportedLogs().count, 0)
    }

    func testProcessHangDiagnosticsWithMockHang() {
      let mockHang = MockMXHangDiagnostic()
      AwsMetricKitHangProcessor.processHangDiagnostics([mockHang])

      let logs = logExporter.getExportedLogs()
      XCTAssertEqual(logs.count, 1)

      let log = logs[0]
      XCTAssertEqual(log.body?.description, "hang")
      XCTAssertEqual(log.instrumentationScopeInfo.name, "aws-otel-swift.MXHangDiagnostic")
      XCTAssertEqual(log.attributes["hang.hang_duration"]?.description, String(Double(Measurement<UnitDuration>(value: 2, unit: UnitDuration.seconds).value.toNanoseconds)))
      XCTAssertEqual(log.attributes["hang.stacktrace"]?.description, "{\"test\":\"stacktrace\"}")
    }

    func testBuildHangAttributesWithMockHang() {
      let mockHang = MockMXHangDiagnostic()
      let attributes = AwsMetricKitHangProcessor.buildHangAttributes(from: mockHang)

      XCTAssertEqual(attributes["hang.hang_duration"]?.description, String(Double(Measurement<UnitDuration>(value: 2, unit: UnitDuration.seconds).value.toNanoseconds)))
      XCTAssertEqual(attributes["hang.stacktrace"]?.description, "{\"test\":\"stacktrace\"}")
    }
  }

  @available(iOS 15.0, *)
  private class MockMXHangDiagnostic: MXHangDiagnostic {
    override var hangDuration: Measurement<UnitDuration> { return Measurement(value: 2, unit: .seconds) }
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
