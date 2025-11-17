/*
 * Copyright Amazon.com, Inc. or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsDeviceKitSpanProcessorTests: XCTestCase {
  var spanProcessor: AwsDeviceKitSpanProcessor!
  var mockSpan: DeviceKitMockReadableSpan!

  override func setUp() {
    super.setUp()
    spanProcessor = AwsDeviceKitSpanProcessor()
    mockSpan = DeviceKitMockReadableSpan()
  }

  func testInitialization() {
    XCTAssertTrue(spanProcessor.isStartRequired)
    XCTAssertFalse(spanProcessor.isEndRequired)
  }

  func testOnStartAddsDeviceKitAttributes() {
    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    #if os(iOS) || os(tvOS)
      if AwsDeviceKitManager.shared.getBatteryLevel() != nil {
        XCTAssertNotNil(mockSpan.capturedAttributes[AwsDeviceKitSemConv.batteryCharge])
      }
    #endif

    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
      if AwsDeviceKitManager.shared.getCPUUtil() != nil {
        XCTAssertNotNil(mockSpan.capturedAttributes[AwsDeviceKitSemConv.cpuUtilization])
      }
      if AwsDeviceKitManager.shared.getMemoryUsage() != nil {
        XCTAssertNotNil(mockSpan.capturedAttributes[AwsDeviceKitSemConv.memoryUsage])
      }
    #endif
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
}

class DeviceKitMockReadableSpan: ReadableSpan {
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
