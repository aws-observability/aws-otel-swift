import XCTest
@testable import AwsOpenTelemetryCore
import OpenTelemetryApi
import OpenTelemetrySdk

class MockAppLaunchProvider: AppLaunchProvider {
  var coldLaunchStartTime: Date?
  var coldStartName: String = "mock.cold.start"
  var warmStartNotification: Notification.Name = .init("mock.warm.start")
  var launchEndNotification: Notification.Name = .init("mock.launch.end")
  var preWarmFallbackThreshold: TimeInterval = 30.0
  var hiddenNotification: Notification.Name = .init("mock.hidden")
  var additionalLifecycleEvents: [Notification.Name] = []

  init() {
    // Provide a default cold launch start time
    coldLaunchStartTime = Date().addingTimeInterval(-1.0)
  }
}

class MockSpanExporter: SpanExporter {
  var exportedSpans: [SpanData] = []

  func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    exportedSpans.append(contentsOf: spans)
    return .success
  }

  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return .success
  }

  func shutdown(explicitTimeout: TimeInterval?) {}
}

class MockLogExporter: LogRecordExporter {
  var exportedLogs: [ReadableLogRecord] = []

  func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    exportedLogs.append(contentsOf: logRecords)
    return .success
  }

  func shutdown(explicitTimeout: TimeInterval?) {}

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}

final class AwsAppLaunchInstrumentationTests: XCTestCase {
  var mockProvider: MockAppLaunchProvider!
  var instrumentation: AwsAppLaunchInstrumentation!
  var spanExporter: MockSpanExporter!
  var logExporter: MockLogExporter!
  var tracerProvider: TracerProviderSdk!
  var loggerProvider: LoggerProviderSdk!

  override func setUp() {
    super.setUp()
    mockProvider = MockAppLaunchProvider()

    // Set up mock exporters
    spanExporter = MockSpanExporter()
    logExporter = MockLogExporter()

    // Create providers with mock exporters
    tracerProvider = TracerProviderBuilder()
      .add(spanProcessor: BatchSpanProcessor(spanExporter: spanExporter))
      .build()

    loggerProvider = LoggerProviderSdk(
      logRecordProcessors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)]
    )

    // Reset static state manually
    AwsAppLaunchInstrumentation.hasLaunched = false
    AwsAppLaunchInstrumentation.hasLostFocusBefore = false
    AwsAppLaunchInstrumentation.lastWarmLaunchStart = nil
    AwsAppLaunchInstrumentation.provider = nil
    AwsAppLaunchInstrumentation.tracer = tracerProvider.get(instrumentationName: "test")
    AwsAppLaunchInstrumentation.logger = loggerProvider.get(instrumentationScopeName: "test")
  }

  override func tearDown() {
    instrumentation = nil
    mockProvider = nil
    spanExporter = nil
    logExporter = nil
    tracerProvider = nil
    loggerProvider = nil
    super.tearDown()
  }

  func testColdLaunchRecording() {
    // Given
    let startTime = Date().addingTimeInterval(-2.0)
    mockProvider.coldLaunchStartTime = startTime
    mockProvider.coldStartName = "test.cold.start"

    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    // When
    instrumentation.onLaunchEnd()

    // Force flush to ensure spans are exported
    tracerProvider.forceFlush()

    // Then
    XCTAssertEqual(spanExporter.exportedSpans.count, 1)
    let span = spanExporter.exportedSpans.first!
    XCTAssertEqual(span.name, "AppStart")
    XCTAssertEqual(span.startTime, startTime)
    XCTAssertEqual(span.attributes["start.type"]?.description, "cold")
    XCTAssertEqual(span.attributes["launch_start_name"]?.description, "test.cold.start")
  }

  func testPrewarmLaunchDetection() {
    // Given - Long duration should trigger prewarm detection
    let startTime = Date().addingTimeInterval(-35.0) // 35 seconds ago
    mockProvider.coldLaunchStartTime = startTime
    mockProvider.preWarmFallbackThreshold = 30.0

    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    // When
    instrumentation.onLaunchEnd()

    // Force flush to ensure spans are exported
    tracerProvider.forceFlush()

    // Then
    XCTAssertEqual(spanExporter.exportedSpans.count, 1)
    let span = spanExporter.exportedSpans.first!
    XCTAssertEqual(span.attributes["start.type"]?.description, "prewarm")
  }

  func testWarmLaunchRecording() {
    // Given - No cold launch start time to avoid cold launch
    mockProvider.coldLaunchStartTime = nil
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)
    instrumentation.onHidden() // Mark as having lost focus

    // When - Warm start followed by launch end
    instrumentation.onWarmStart()
    Thread.sleep(forTimeInterval: 0.1) // Small delay
    instrumentation.onLaunchEnd()

    // Force flush to ensure spans are exported
    tracerProvider.forceFlush()

    // Then
    XCTAssertEqual(spanExporter.exportedSpans.count, 1)
    let span = spanExporter.exportedSpans.first!
    XCTAssertEqual(span.name, "AppStart")
    XCTAssertEqual(span.attributes["start.type"]?.description, "warm")
    XCTAssertEqual(span.attributes["active_prewarm"]?.description, "false")
  }

  func testNoColdLaunchWhenStartTimeUnavailable() {
    // Given
    mockProvider.coldLaunchStartTime = nil
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    // When
    instrumentation.onLaunchEnd()

    // Then
    XCTAssertEqual(spanExporter.exportedSpans.count, 0)
  }

  func testNoWarmLaunchWithoutPriorHidden() {
    // Given - No cold launch start time to avoid cold launch
    mockProvider.coldLaunchStartTime = nil
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    // When - Warm start without having been hidden first
    instrumentation.onWarmStart()
    instrumentation.onLaunchEnd()

    // Force flush to ensure spans are exported
    tracerProvider.forceFlush()

    // Then - Should not record warm launch
    XCTAssertEqual(spanExporter.exportedSpans.count, 0)
  }

  func testLifecycleEventLogging() {
    // Given
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    // When
    instrumentation.onLifecycleEvent(name: "test.lifecycle.event")

    // Then
    XCTAssertEqual(logExporter.exportedLogs.count, 1)
    let logRecord = logExporter.exportedLogs.first!
    XCTAssertEqual(logRecord.eventName, "test.lifecycle.event")
  }

  func testOnlyOneColdLaunchPerLifecycle() {
    // Given
    let startTime = Date().addingTimeInterval(-1.0)
    mockProvider.coldLaunchStartTime = startTime
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    // When - Multiple launch end calls
    instrumentation.onLaunchEnd()
    instrumentation.onLaunchEnd()

    // Force flush to ensure spans are exported
    tracerProvider.forceFlush()

    // Then - Only one span recorded
    XCTAssertEqual(spanExporter.exportedSpans.count, 1)
  }

  func testWarmLaunchClearsAfterRecording() {
    // Given - No cold launch start time to avoid cold launch
    mockProvider.coldLaunchStartTime = nil
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)
    instrumentation.onHidden()
    instrumentation.onWarmStart()

    // When - First launch end
    instrumentation.onLaunchEnd()
    // Second launch end without new warm start
    instrumentation.onLaunchEnd()

    // Force flush to ensure spans are exported
    tracerProvider.forceFlush()

    // Then - Only one warm launch recorded
    XCTAssertEqual(spanExporter.exportedSpans.count, 1)
  }

  func testStaticMethodsCallInstanceMethods() {
    // Given
    AwsAppLaunchInstrumentation.provider = mockProvider

    // When - Call static methods
    AwsAppLaunchInstrumentation.onLifecycleEvent(name: "static.test")

    // Then
    XCTAssertEqual(logExporter.exportedLogs.count, 1)
  }

  func testIsPrewarmDetection() {
    // Given
    mockProvider.preWarmFallbackThreshold = 30.0
    AwsAppLaunchInstrumentation.provider = mockProvider

    // When/Then - Short duration should not be prewarm
    XCTAssertFalse(AwsAppLaunchInstrumentation.isPrewarm(duration: 2.0))

    // When/Then - Long duration should be prewarm
    XCTAssertTrue(AwsAppLaunchInstrumentation.isPrewarm(duration: 35.0))
  }

  func testStaticStateAccess() {
    // Given/When - Set static state
    AwsAppLaunchInstrumentation.hasLaunched = true
    AwsAppLaunchInstrumentation.hasLostFocusBefore = true
    AwsAppLaunchInstrumentation.lastWarmLaunchStart = Date()

    // Then - Verify state is accessible
    XCTAssertTrue(AwsAppLaunchInstrumentation.hasLaunched)
    XCTAssertTrue(AwsAppLaunchInstrumentation.hasLostFocusBefore)
    XCTAssertNotNil(AwsAppLaunchInstrumentation.lastWarmLaunchStart)
  }
}
