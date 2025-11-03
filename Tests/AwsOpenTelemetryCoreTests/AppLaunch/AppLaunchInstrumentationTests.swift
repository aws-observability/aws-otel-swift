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

  func testNoLaunchWhenConditionsNotMet() {
    mockProvider.coldLaunchStartTime = nil
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    // Test no cold launch when start time unavailable
    instrumentation.onLaunchEnd()
    XCTAssertEqual(spanExporter.exportedSpans.count, 0)

    // Test no warm launch without prior hidden
    instrumentation.onWarmStart()
    instrumentation.onLaunchEnd()
    tracerProvider.forceFlush()
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

  func testIsPrewarmDetection() {
    mockProvider.preWarmFallbackThreshold = 30.0
    AwsAppLaunchInstrumentation.provider = mockProvider

    XCTAssertFalse(AwsAppLaunchInstrumentation.isPrewarm(duration: 2.0))
    XCTAssertTrue(AwsAppLaunchInstrumentation.isPrewarm(duration: 35.0))

    // Test edge cases
    AwsAppLaunchInstrumentation.provider = nil
    XCTAssertFalse(AwsAppLaunchInstrumentation.isPrewarm(duration: 35.0))

    mockProvider.preWarmFallbackThreshold = 0
    AwsAppLaunchInstrumentation.provider = mockProvider
    XCTAssertFalse(AwsAppLaunchInstrumentation.isPrewarm(duration: 35.0))
  }

  func testInstrumentationSetup() {
    XCTAssertEqual(AwsAppLaunchInstrumentation.instrumentationKey, AwsInstrumentationScopes.APP_START)

    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)
    XCTAssertNotNil(instrumentation.launchEndObserver)
    XCTAssertNotNil(instrumentation.warmStartObserver)
    XCTAssertNotNil(instrumentation.hiddenObserver)
  }

  func testLifecycleObserverSetup() {
    mockProvider.additionalLifecycleEvents = [
      Notification.Name("test.event1"),
      Notification.Name("test.event2")
    ]

    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    XCTAssertEqual(instrumentation.lifecycleObservers.count, 2)
    XCTAssertNotNil(instrumentation.lifecycleObservers["test.event1"])
    XCTAssertNotNil(instrumentation.lifecycleObservers["test.event2"])
  }

  func testDuplicateLifecycleObserverSkipped() {
    let duplicateEvent = Notification.Name("duplicate.event")
    mockProvider.additionalLifecycleEvents = [duplicateEvent, duplicateEvent]

    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    XCTAssertEqual(instrumentation.lifecycleObservers.count, 1)
  }

  func testHiddenObserverRemovedAfterFirstUse() {
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    XCTAssertNotNil(instrumentation.hiddenObserver)

    // Post the actual notification to trigger the observer removal
    NotificationCenter.default.post(name: mockProvider.hiddenNotification, object: nil)

    // Give the notification time to process
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    XCTAssertNil(instrumentation.hiddenObserver)
  }

  func testStaticMethods() {
    // Test with valid provider
    AwsAppLaunchInstrumentation.provider = mockProvider
    AwsAppLaunchInstrumentation.onLifecycleEvent(name: "static.test")
    XCTAssertEqual(logExporter.exportedLogs.count, 1)

    // Test with nil provider
    AwsAppLaunchInstrumentation.provider = nil
    XCTAssertNoThrow(AwsAppLaunchInstrumentation.onLaunchEnd())
    XCTAssertNoThrow(AwsAppLaunchInstrumentation.onWarmStart())
    XCTAssertNoThrow(AwsAppLaunchInstrumentation.onHidden())
  }

  func testLaunchDeduplication() {
    // Test cold launch only recorded once
    mockProvider.coldLaunchStartTime = Date().addingTimeInterval(-1.0)
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)

    instrumentation.onLaunchEnd()
    instrumentation.onLaunchEnd()
    tracerProvider.forceFlush()
    XCTAssertEqual(spanExporter.exportedSpans.count, 1)

    // Test warm launch without warm start
    mockProvider.coldLaunchStartTime = nil
    instrumentation = AwsAppLaunchInstrumentation(provider: mockProvider)
    instrumentation.onHidden()
    instrumentation.onLaunchEnd()
    tracerProvider.forceFlush()
    XCTAssertEqual(spanExporter.exportedSpans.count, 1) // Still only 1 from cold launch
  }
}
