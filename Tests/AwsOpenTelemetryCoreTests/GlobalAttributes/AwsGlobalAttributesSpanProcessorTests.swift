import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsGlobalAttributesSpanProcessorTests: XCTestCase {
  var mockGlobalAttributesManager: SpanProcessorMockGlobalAttributesManager!
  var spanProcessor: AwsGlobalAttributesSpanProcessor!
  var mockSpan: GlobalAttributesMockReadableSpan!

  override func setUp() {
    super.setUp()
    mockGlobalAttributesManager = SpanProcessorMockGlobalAttributesManager()
    spanProcessor = AwsGlobalAttributesSpanProcessor(globalAttributesManager: mockGlobalAttributesManager)
    mockSpan = GlobalAttributesMockReadableSpan()
  }

  func testInitialization() {
    XCTAssertTrue(spanProcessor.isStartRequired)
    XCTAssertFalse(spanProcessor.isEndRequired)
  }

  func testOnStartAddsGlobalAttributes() {
    mockGlobalAttributesManager.attributes = [
      "global.key1": AttributeValue.string("value1"),
      "global.key2": AttributeValue.int(42)
    ]

    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    XCTAssertEqual(mockSpan.capturedAttributes["global.key1"], AttributeValue.string("value1"))
    XCTAssertEqual(mockSpan.capturedAttributes["global.key2"], AttributeValue.int(42))
  }

  func testOnStartWithEmptyGlobalAttributes() {
    mockGlobalAttributesManager.attributes = [:]

    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    XCTAssertTrue(mockSpan.capturedAttributes.isEmpty)
  }

  func testOnEndDoesNothing() {
    spanProcessor.onEnd(span: mockSpan)
  }

  func testShutdownDoesNothing() {
    spanProcessor.shutdown(explicitTimeout: 5.0)
  }

  func testForceFlushDoesNothing() {
    spanProcessor.forceFlush(timeout: 5.0)
  }

  func testInitializationWithNilGlobalAttributesManager() {
    let processor = AwsGlobalAttributesSpanProcessor(globalAttributesManager: nil)
    XCTAssertTrue(processor.isStartRequired)
    XCTAssertFalse(processor.isEndRequired)
  }
}

class SpanProcessorMockGlobalAttributesManager: AwsGlobalAttributesManager {
  var attributes: [String: AttributeValue] = [:]

  override func getAttributes() -> [String: AttributeValue] {
    return attributes
  }
}

class GlobalAttributesMockReadableSpan: ReadableSpan {
  var capturedAttributes: [String: AttributeValue] = [:]

  var hasEnded: Bool = false
  var latency: TimeInterval = 0
  var kind: SpanKind = .client
  var instrumentationScopeInfo = InstrumentationScopeInfo()
  var name: String = "MockSpan"
  var context: SpanContext = .create(traceId: TraceId.random(), spanId: SpanId.random(), traceFlags: TraceFlags(), traceState: TraceState())
  var isRecording: Bool = true
  var status: Status = .unset
  var description: String = "MockReadableSpan"

  func getAttributes() -> [String: AttributeValue] {
    return capturedAttributes
  }

  func setAttributes(_ attributes: [String: AttributeValue]) {
    capturedAttributes.merge(attributes) { _, new in new }
  }

  func end() {}
  func end(time: Date) {}

  func toSpanData() -> SpanData {
    return SpanData(traceId: context.traceId,
                    spanId: context.spanId,
                    traceFlags: context.traceFlags,
                    traceState: TraceState(),
                    resource: Resource(attributes: [String: AttributeValue]()),
                    instrumentationScope: InstrumentationScopeInfo(),
                    name: name,
                    kind: kind,
                    startTime: Date(),
                    endTime: Date(),
                    hasRemoteParent: false)
  }

  func setAttribute(key: String, value: AttributeValue?) {
    if let value {
      capturedAttributes[key] = value
    }
  }

  func addEvent(name: String) {}
  func addEvent(name: String, attributes: [String: AttributeValue]) {}
  func addEvent(name: String, timestamp: Date) {}
  func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}
  func recordException(_ exception: SpanException) {}
  func recordException(_ exception: any SpanException, timestamp: Date) {}
  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue]) {}
  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue], timestamp: Date) {}
}
