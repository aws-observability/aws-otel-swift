#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import XCTest
  import MetricKit
  import OpenTelemetryApi
  @testable import AwsOpenTelemetryCore
  @testable import TestUtils

  @available(iOS 15.0, *)
  final class AwsMetricKitHangProcessorTests: XCTestCase {
    private var spanExporter: InMemorySpanExporter!

    override func setUp() {
      super.setUp()
      spanExporter = InMemorySpanExporter.register()
    }

    override func tearDown() {
      spanExporter.clear()
      super.tearDown()
    }

    func testScopeName() {
      XCTAssertEqual(AwsMetricKitHangProcessor.scopeName, "software.amazon.opentelemetry.MXHangDiagnostic")
    }

    func testProcessHangDiagnosticsWithNilDiagnostics() {
      AwsMetricKitHangProcessor.processHangDiagnostics(nil)
      XCTAssertEqual(spanExporter.getExportedSpans().count, 0)
    }

    func testProcessHangDiagnosticsWithEmptyDiagnostics() {
      AwsMetricKitHangProcessor.processHangDiagnostics([])
      XCTAssertEqual(spanExporter.getExportedSpans().count, 0)
    }

    func testProcessHangDiagnosticsWithMockHang() {
      let mockHang = MockMXHangDiagnostic()
      AwsMetricKitHangProcessor.processHangDiagnostics([mockHang])

      let expectation = XCTestExpectation(description: "Wait for span export")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        expectation.fulfill()
      }
      wait(for: [expectation], timeout: 1.0)

      let spans = spanExporter.getExportedSpans()
      XCTAssertEqual(spans.count, 1, "Expected 1 span but got \(spans.count)")

      guard spans.count > 0 else {
        XCTFail("No spans were exported")
        return
      }

      let span = spans[0]
      XCTAssertEqual(span.name, "hang")
      XCTAssertEqual(span.instrumentationScope.name, "software.amazon.opentelemetry.MXHangDiagnostic")
      XCTAssertEqual(span.attributes[AwsMetricKitConstants.hangDuration]?.description, String(Double(Measurement<UnitDuration>(value: 2, unit: UnitDuration.seconds).value.toNanoseconds)))
      XCTAssertEqual(span.attributes[AwsMetricKitConstants.hangCallStackTree]?.description, "{\"test\":\"stacktrace\"}")
    }

    func testBuildHangAttributesWithMockHang() {
      let mockHang = MockMXHangDiagnostic()
      let attributes = AwsMetricKitHangProcessor.buildHangAttributes(from: mockHang)

      XCTAssertEqual(attributes[AwsMetricKitConstants.hangDuration]?.description, String(Double(Measurement<UnitDuration>(value: 2, unit: UnitDuration.seconds).value.toNanoseconds)))
      XCTAssertEqual(attributes[AwsMetricKitConstants.hangCallStackTree]?.description, "{\"test\":\"stacktrace\"}")
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
