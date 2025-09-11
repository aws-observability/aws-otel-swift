#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import XCTest
  import MetricKit
  import OpenTelemetryApi
  @testable import AwsOpenTelemetryCore
  @testable import TestUtils

  @available(iOS 16.0, *)
  final class AwsMetricKitAppLaunchProcessorTests: XCTestCase {
    private var spanExporter: InMemorySpanExporter!

    override func setUp() {
      super.setUp()
      spanExporter = InMemorySpanExporter.register()
      AwsMetricKitAppLaunchProcessor.resetForTesting()
      AwsMetricKitAppLaunchProcessor.initialize()
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

      // Add a small delay to ensure async operations complete
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
      XCTAssertEqual(span.name, "AppStart")
      XCTAssertEqual(span.instrumentationScope.name, "software.amazon.opentelemetry.MXAppLaunchDiagnostic")
      XCTAssertEqual(span.attributes[AwsMetricKitConstants.appLaunchDuration]?.description, "2.5")
      XCTAssertEqual(span.attributes[AwsMetricKitConstants.appLaunchType]?.description, "COLD")
    }

    func testColdStartDetection() {
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

      let mockLaunch = MockMXAppLaunchDiagnostic()
      AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics([mockLaunch])

      // Add a small delay to ensure async operations complete
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

      XCTAssertEqual(spans[0].attributes[AwsMetricKitConstants.appLaunchType]?.description, "COLD")
    }

    func testSkipsLongLaunchDuration() {
      // Simulate app becoming active
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

      // Create diagnostic with duration > 3 minutes
      let longLaunchDiagnostic = MockLongMXAppLaunchDiagnostic()
      AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics([longLaunchDiagnostic])

      let spans = spanExporter.getExportedSpans()
      XCTAssertEqual(spans.count, 0, "Expected no spans for long launch duration")
    }

    func testCachesDiagnosticWhenAppNotActive() {
      // Process diagnostic before app becomes active
      let diagnostic = MockMXAppLaunchDiagnostic()
      AwsMetricKitAppLaunchProcessor.processAppLaunchDiagnostics([diagnostic])

      // Should have no spans yet
      XCTAssertEqual(spanExporter.getExportedSpans().count, 0)

      // Now simulate app becoming active
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

      // Wait for async processing
      let expectation = XCTestExpectation(description: "Wait for cached diagnostic processing")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        expectation.fulfill()
      }
      wait(for: [expectation], timeout: 1.0)

      // Should now have the span from cached diagnostic
      let spans = spanExporter.getExportedSpans()
      XCTAssertEqual(spans.count, 1, "Expected 1 span from cached diagnostic")
    }
  }

  @available(iOS 16.0, *)
  private class MockMXAppLaunchDiagnostic: MXAppLaunchDiagnostic {
    override var launchDuration: Measurement<UnitDuration> {
      return Measurement(value: 2.5, unit: .seconds)
    }
  }

  @available(iOS 16.0, *)
  private class MockLongMXAppLaunchDiagnostic: MXAppLaunchDiagnostic {
    override var launchDuration: Measurement<UnitDuration> {
      return Measurement(value: 300, unit: .seconds) // 5 minutes
    }
  }
#endif
