import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk
@testable import TestUtils

final class AwsScreenSpanProcessorTests: XCTestCase {
  var screenManager: AwsScreenManager!
  var spanProcessor: AwsScreenSpanProcessor!
  var mockSpan: ScreenMockReadableSpan!

  override func setUp() {
    super.setUp()
    screenManager = AwsScreenManager()
    spanProcessor = AwsScreenSpanProcessor(screenManager: screenManager)
    mockSpan = ScreenMockReadableSpan()
  }

  func testInitialization() {
    XCTAssertTrue(spanProcessor.isStartRequired)
    XCTAssertFalse(spanProcessor.isEndRequired)
  }

  func testOnStartAddsScreenName() {
    screenManager.setCurrent(screen: "HomeScreen")

    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    XCTAssertEqual(mockSpan.capturedAttributes[AwsViewSemConv.screenName], AttributeValue.string("HomeScreen"))
  }

  func testOnStartWithNilScreenName() {
    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    XCTAssertNil(mockSpan.capturedAttributes[AwsViewSemConv.screenName])
  }

  func testOnStartDoesNotOverrideExistingScreenName() {
    screenManager.setCurrent(screen: "HomeScreen")
    mockSpan.capturedAttributes[AwsViewSemConv.screenName] = AttributeValue.string("ExistingScreen")

    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    XCTAssertEqual(mockSpan.capturedAttributes[AwsViewSemConv.screenName], AttributeValue.string("ExistingScreen"))
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

  func testInitializationWithNilScreenManager() {
    let processor = AwsScreenSpanProcessor(screenManager: nil)
    XCTAssertTrue(processor.isStartRequired)
    XCTAssertFalse(processor.isEndRequired)
  }
}

class ScreenMockReadableSpan: ReadableSpan {
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
    fatalError("Not implemented")
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
