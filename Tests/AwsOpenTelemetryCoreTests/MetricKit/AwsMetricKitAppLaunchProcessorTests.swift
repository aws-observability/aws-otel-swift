#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import XCTest
  import MetricKit
  import OpenTelemetryApi
  import OpenTelemetrySdk
  @testable import AwsOpenTelemetryCore
  @testable import TestUtils

  @available(iOS 16.0, *)
  final class AwsMetricKitAppLaunchProcessorTests: XCTestCase {
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
      XCTAssertEqual(AwsMetricKitAppLaunchProcessor.scopeName, "software.amazon.opentelemetry.MXAppLaunchDiagnostic")
    }

    func testProcessAppLaunchDiagnosticsWithNilDiagnostics() {
      AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics(nil)
      XCTAssertEqual(spanExporter.getExportedSpans().count, 0)
    }

    func testProcessAppLaunchDiagnosticsWithEmptyDiagnostics() {
      AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics([])
      XCTAssertEqual(spanExporter.getExportedSpans().count, 0)
    }

    func testProcessAppLaunchDiagnosticsWithoutActiveTime() {
      let mockLaunch = MockMXAppLaunchDiagnostic()
      AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics([mockLaunch])

      // Should skip creating span without app active time
      XCTAssertEqual(spanExporter.getExportedSpans().count, 0)
    }

    func testProcessAppLaunchDiagnosticsWithMockLaunch() {
      // Simulate app becoming active
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

      let mockLaunch = MockMXAppLaunchDiagnostic()
      AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics([mockLaunch])

      let spans = spanExporter.getExportedSpans()
      XCTAssertEqual(spans.count, 1)

      let span = spans[0]
      XCTAssertEqual(span.name, "AppStart")
      XCTAssertEqual(span.instrumentationScopeInfo.name, "software.amazon.opentelemetry.MXAppLaunchDiagnostic")
      XCTAssertEqual(span.attributes[AwsMetricKitConstants.appLaunchDuration]?.description, "2.5")
      XCTAssertEqual(span.attributes[AwsMetricKitConstants.appLaunchType]?.description, "COLD")
    }

    func testColdStartDetection() {
      // Reset to cold start state
      AwsMetricKitAppLaunchProcessor.initialize()

      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

      let mockLaunch = MockMXAppLaunchDiagnostic()
      AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics([mockLaunch])

      let spans = spanExporter.getExportedSpans()
      XCTAssertEqual(spans.count, 1)
      XCTAssertEqual(spans[0].attributes[AwsMetricKitConstants.appLaunchType]?.description, "WARM")
    }
  }

  @available(iOS 16.0, *)
  private class MockMXAppLaunchDiagnostic: MXAppLaunchDiagnostic {
    override var launchDuration: Measurement<UnitDuration> {
      return Measurement(value: 2.5, unit: .seconds)
    }
  }
#endif
