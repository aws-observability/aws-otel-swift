import XCTest
@testable import AwsOpenTelemetryCore
import OpenTelemetryApi
import OpenTelemetrySdk

// Simple in-memory exporter for testing
class InMemorySpanExporter: SpanExporter {
  private var finishedSpans: [SpanData] = []

  func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    finishedSpans.append(contentsOf: spans)
    return .success
  }

  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return .success
  }

  func shutdown(explicitTimeout: TimeInterval?) {}

  func getFinishedSpans() -> [SpanData] {
    return finishedSpans
  }

  func reset() {
    finishedSpans.removeAll()
  }
}

final class AwsOpenTelemetryAgentTests: XCTestCase {
  // Define test values
  let version = "1.0.0"
  let region = "us-west-2"
  let appMonitorId = "test-monitor-id"
  let appVersion = "1.0.0"
  let logsEndpoint = "https://example.com/logs"
  let tracesEndpoint = "https://example.com/traces"

  // Reset the shared instance state between tests
  override func tearDown() {
    // Reset the shared instance state directly for testing purposes
    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
    super.tearDown()
  }

  func testManualInitialization() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: .init(region: region, appMonitorId: appMonitorId),
      application: .init(applicationVersion: appVersion)
    )

    // Initialize the SDK
    let result = AwsOpenTelemetryAgent.shared.initialize(config: config)

    // Verify initialization was successful
    XCTAssertTrue(result)
    XCTAssertTrue(AwsOpenTelemetryAgent.shared.isInitialized)
    XCTAssertNotNil(AwsOpenTelemetryAgent.shared.configuration)
    XCTAssertEqual(AwsOpenTelemetryAgent.shared.configuration?.rum.region, region)
    XCTAssertEqual(AwsOpenTelemetryAgent.shared.configuration?.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(AwsOpenTelemetryAgent.shared.configuration?.application.applicationVersion, appVersion)
  }

  func testDoubleInitialization() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: .init(region: region, appMonitorId: appMonitorId),
      application: .init(applicationVersion: appVersion)
    )

    // First initialization should succeed
    let firstResult = AwsOpenTelemetryAgent.shared.initialize(config: config)
    XCTAssertTrue(firstResult)

    // Second initialization should fail
    let secondResult = AwsOpenTelemetryAgent.shared.initialize(config: config)
    XCTAssertFalse(secondResult)
  }

  func testConfigParsing() throws {
    // Create a JSON string with valid configuration
    let jsonString = """
    {
        "version": "\(version)",
        "rum": {
            "region": "\(region)",
            "appMonitorId": "\(appMonitorId)",
            "overrideEndpoint": {
                "logs": "\(logsEndpoint)",
                "traces": "\(tracesEndpoint)"
            }
        },
        "application": {
            "applicationVersion": "\(appVersion)"
        }
    }
    """

    // Parse the configuration
    let data = jsonString.data(using: .utf8)!
    let config = try AwsRumConfigReader.parseConfig(from: data)

    // Verify the parsed configuration
    XCTAssertEqual(config.version, version)
    XCTAssertEqual(config.rum.region, region)
    XCTAssertEqual(config.rum.appMonitorId, appMonitorId)
    XCTAssertEqual(config.rum.overrideEndpoint?.logs, logsEndpoint)
    XCTAssertEqual(config.rum.overrideEndpoint?.traces, tracesEndpoint)
    XCTAssertEqual(config.application.applicationVersion, appVersion)
  }

  func testSpanProperties() {
    // Create a simple TracerProvider for testing
    let exporter = InMemorySpanExporter()
    let spanProcessor = SimpleSpanProcessor(spanExporter: exporter)
    let tracerProvider = TracerProviderBuilder()
      .add(spanProcessor: spanProcessor)
      .build()

    // Register the tracer provider with OpenTelemetry
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

    // Get a tracer from AwsOpenTelemetryAgent
    let tracer = AwsOpenTelemetryAgent.getTracer()

    // Create a span with specific properties
    let spanName = "test-span-properties"
    let span = tracer.spanBuilder(spanName: spanName)
      .setSpanKind(spanKind: .client)
      .startSpan()

    // Add events and links to the span
    span.addEvent(name: "test-event")
    span.addEvent(name: "test-event-with-attributes", attributes: ["event.key": AttributeValue.string("event-value")])

    // End the span
    span.end()

    // Wait briefly for span processing
    Thread.sleep(forTimeInterval: 0.1)

    // Get the exported spans
    let finishedSpans = exporter.getFinishedSpans()
    XCTAssertFalse(finishedSpans.isEmpty, "Should have at least one finished span")

    if let exportedSpan = finishedSpans.first {
      // Verify span name
      XCTAssertEqual(exportedSpan.name, spanName, "Span name should match")

      // Verify span kind
      XCTAssertEqual(exportedSpan.kind, .client, "Span kind should be client")

      // Verify span has a valid trace ID and span ID
      XCTAssertFalse(exportedSpan.traceId.hexString.isEmpty, "Span should have a valid trace ID")
      XCTAssertFalse(exportedSpan.spanId.hexString.isEmpty, "Span should have a valid span ID")

      // Verify span has events
      XCTAssertEqual(exportedSpan.events.count, 2, "Span should have 2 events")

      // Verify first event
      let firstEvent = exportedSpan.events[0]
      XCTAssertEqual(firstEvent.name, "test-event", "First event name should match")
      XCTAssertTrue(firstEvent.attributes.isEmpty, "First event should have no attributes")

      // Verify second event with attributes
      let secondEvent = exportedSpan.events[1]
      XCTAssertEqual(secondEvent.name, "test-event-with-attributes", "Second event name should match")
      XCTAssertFalse(secondEvent.attributes.isEmpty, "Second event should have attributes")

      let eventAttribute = secondEvent.attributes.first { $0.key == "event.key" }
      XCTAssertNotNil(eventAttribute, "Event should have event.key attribute")
      XCTAssertEqual(eventAttribute?.value.description, "event-value")

      // Verify span status (default should be unset)
      XCTAssertEqual(exportedSpan.status, Status.unset, "Default span status should be unset")

      // Verify span has start and end timestamps
      XCTAssertGreaterThan(exportedSpan.endTime, exportedSpan.startTime, "End time should be after start time")
    } else {
      XCTFail("No spans were exported")
    }
  }

  func testSDKVersionAndName() {
    // Create a simple TracerProvider for testing
    let exporter = InMemorySpanExporter()
    let spanProcessor = SimpleSpanProcessor(spanExporter: exporter)
    let tracerProvider = TracerProviderBuilder()
      .add(spanProcessor: spanProcessor)
      .build()

    // Register the tracer provider with OpenTelemetry
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

    // Get a tracer from AwsOpenTelemetryAgent
    let tracer = AwsOpenTelemetryAgent.getTracer()

    // Create and end a simple span
    let span = tracer.spanBuilder(spanName: "test-span").startSpan()
    span.end()

    // Wait briefly for span processing
    Thread.sleep(forTimeInterval: 0.1)

    // Get the exported spans
    let finishedSpans = exporter.getFinishedSpans()
    XCTAssertFalse(finishedSpans.isEmpty, "Should have at least one finished span")

    if let exportedSpan = finishedSpans.first {
      // Verify instrumentation scope has correct name and version
      XCTAssertEqual(exportedSpan.instrumentationScope.name, AwsOpenTelemetryAgent.name,
                     "Instrumentation scope name should match AwsOpenTelemetryAgent.name")
      XCTAssertEqual(exportedSpan.instrumentationScope.version, AwsOpenTelemetryAgent.version,
                     "Instrumentation scope version should match AwsOpenTelemetryAgent.version")
    } else {
      XCTFail("No spans were exported")
    }
  }
}
