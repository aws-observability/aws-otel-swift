import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsUIDSpanProcessorTests: XCTestCase {
  var spanProcessor: AwsUIDSpanProcessor!
  var mockSpan: MockReadableSpan!

  override func setUp() {
    super.setUp()
    // Clear any existing UID for clean tests
    UserDefaults.standard.removeObject(forKey: "aws-rum-user-id")
    spanProcessor = AwsUIDSpanProcessor()
    mockSpan = MockReadableSpan()
  }

  func testInitialization() {
    XCTAssertTrue(spanProcessor.isStartRequired)
    XCTAssertFalse(spanProcessor.isEndRequired)
  }

  func testOnStartAddsUID() {
    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    XCTAssertTrue(mockSpan.capturedAttributes.keys.contains("user.id"))
    let uidValue = mockSpan.capturedAttributes["user.id"]
    XCTAssertNotNil(uidValue)
  }

  func testUIDConsistencyAcrossSpans() {
    let mockSpan2 = MockReadableSpan()

    spanProcessor.onStart(parentContext: nil, span: mockSpan)
    spanProcessor.onStart(parentContext: nil, span: mockSpan2)

    let uid1 = mockSpan.capturedAttributes["user.id"]
    let uid2 = mockSpan2.capturedAttributes["user.id"]

    XCTAssertEqual(uid1?.description, uid2?.description)
  }

  func testIntegrationWithRegisteredTracer() {
    // Store the original tracer provider to restore later
    let originalProvider = OpenTelemetry.instance.tracerProvider

    // Create a real tracer provider with our UID span processor
    let tracerProvider = TracerProviderBuilder()
      .add(spanProcessor: spanProcessor)
      .build()

    // Register the tracer
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

    // Get a tracer and create a span
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "test-tracer", instrumentationVersion: "1.0.0")
    let span = tracer.spanBuilder(spanName: "test-span").startSpan()

    // End the span to trigger processing
    span.end()

    // Verify the span has the user.id attribute
    if let readableSpan = span as? ReadableSpan {
      let spanData = readableSpan.toSpanData()
      XCTAssertTrue(spanData.attributes.keys.contains("user.id"), "Span should have user.id attribute")

      let userIdValue = spanData.attributes["user.id"]
      XCTAssertNotNil(userIdValue, "user.id attribute should have a value")
    } else {
      XCTFail("Span should be readable")
    }

    // Restore the original tracer provider to avoid affecting other tests
    OpenTelemetry.registerTracerProvider(tracerProvider: originalProvider)
  }
}
