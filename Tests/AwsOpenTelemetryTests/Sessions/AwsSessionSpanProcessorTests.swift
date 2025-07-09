import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsSessionSpanProcessorTests: XCTestCase {
  var mockSessionManager: MockSessionManager!
  var spanProcessor: AwsSessionSpanProcessor!
  var mockSpan: MockReadableSpan!

  override func setUp() {
    super.setUp()
    mockSessionManager = MockSessionManager()
    spanProcessor = AwsSessionSpanProcessor(sessionManager: mockSessionManager)
    mockSpan = MockReadableSpan()
  }

  func testInitialization() {
    XCTAssertTrue(spanProcessor.isStartRequired)
    XCTAssertFalse(spanProcessor.isEndRequired)
    XCTAssertEqual(spanProcessor.sessionSpanKey, "session.id")
  }

  func testOnStartAddsSessionId() {
    let expectedSessionId = "test-session-123"
    mockSessionManager.sessionId = expectedSessionId

    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    if case let .string(sessionId) = mockSpan.capturedAttributes["session.id"] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }
  }

  func testOnStartWithDifferentSessionIds() {
    mockSessionManager.sessionId = "session-1"
    spanProcessor.onStart(parentContext: nil, span: mockSpan)
    if case let .string(sessionId) = mockSpan.capturedAttributes["session.id"] {
      XCTAssertEqual(sessionId, "session-1")
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }

    let anotherSpan = MockReadableSpan()
    mockSessionManager.sessionId = "session-2"
    spanProcessor.onStart(parentContext: nil, span: anotherSpan)
    if case let .string(sessionId) = anotherSpan.capturedAttributes["session.id"] {
      XCTAssertEqual(sessionId, "session-2")
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }
  }

  func testOnEndDoesNothing() {
    spanProcessor.onEnd(span: mockSpan)
    // No assertions needed - just verify it doesn't crash
  }

  func testShutdownDoesNothing() {
    spanProcessor.shutdown(explicitTimeout: 5.0)
    // No assertions needed - just verify it doesn't crash
  }

  func testForceFlushDoesNothing() {
    spanProcessor.forceFlush(timeout: 5.0)
    // No assertions needed - just verify it doesn't crash
  }
}

// MARK: - Mock Classes

class MockSessionManager: AwsSessionManager {
  var sessionId: String = "default-session-id"

  override func getSessionId() -> String {
    return sessionId
  }
}

class MockReadableSpan: ReadableSpan {
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

  func updateName(name: String) {
    self.name = name
  }

  func setAttribute(key: String, value: AttributeValue?) {
    if let value = value {
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
