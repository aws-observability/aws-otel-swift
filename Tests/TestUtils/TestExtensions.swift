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

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class MockURLSession: URLSession {
  public var mockResponse: HTTPURLResponse?
  public var mockError: Error?
  public var mockData: Data?
  public var requestCount = 0

  override public init() {
    super.init()
  }

  override public func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
    requestCount += 1
    return MockURLSessionDataTask {
      completionHandler(self.mockData, self.mockResponse, self.mockError)
    }
  }
}

public class MockURLSessionDataTask: URLSessionDataTask {
  private let closure: () -> Void

  public init(closure: @escaping () -> Void) {
    self.closure = closure
    super.init()
  }

  override public func resume() {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      self.closure()
    }
  }
}

public func TestLogRecord() -> ReadableLogRecord {
  return ReadableLogRecord(
    resource: Resource(),
    instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
    timestamp: Date(),
    observedTimestamp: Date(),
    spanContext: nil,
    severity: .info,
    body: AttributeValue.string("Test log message"),
    attributes: [:]
  )
}

public func TestSpanData() -> SpanData {
  // Create SpanData using a simple approach - create a real span and convert it
  let tracerProvider = TracerProviderBuilder().build()
  let tracer = tracerProvider.get(instrumentationName: "test")
  let span = tracer.spanBuilder(spanName: "test-span").startSpan()
  span.end()

  if let readableSpan = span as? ReadableSpan {
    return readableSpan.toSpanData()
  } else {
    // Fallback: create minimal SpanData using a different approach
    fatalError("Unable to create test SpanData")
  }
}

// MARK: - ReadableSpan Extensions

extension ReadableSpan {
  var testAttributes: [String: AttributeValue] { toSpanData().attributes }
  var testParentSpanId: SpanId? { toSpanData().parentSpanId }
  var testSpanId: SpanId { toSpanData().spanId }
  var isRootSpan: Bool { testParentSpanId == nil }
  var isChildSpan: Bool { testParentSpanId != nil }

  func getAttributeString(_ key: String) -> String? {
    testAttributes[key]?.description
  }

  func getAttributeInt(_ key: String) -> Int? {
    if case let .int(value) = testAttributes[key] { return value }
    return nil
  }

  func getAttributeBool(_ key: String) -> Bool? {
    if case let .bool(value) = testAttributes[key] { return value }
    return nil
  }

  func getAttributeDouble(_ key: String) -> Double? {
    if case let .double(value) = testAttributes[key] { return value }
    return nil
  }
}

// MARK: - SpanData Extensions

extension SpanData {
  var testAttributes: [String: AttributeValue] { attributes }
  var testParentSpanId: SpanId? { parentSpanId }
  var testSpanId: SpanId { spanId }
  var isRootSpan: Bool { testParentSpanId == nil }
  var isChildSpan: Bool { testParentSpanId != nil }

  func getAttributeString(_ key: String) -> String? {
    testAttributes[key]?.description
  }

  func getAttributeInt(_ key: String) -> Int? {
    if case let .int(value) = testAttributes[key] { return value }
    return nil
  }

  func getAttributeBool(_ key: String) -> Bool? {
    if case let .bool(value) = testAttributes[key] { return value }
    return nil
  }

  func getAttributeDouble(_ key: String) -> Double? {
    if case let .double(value) = testAttributes[key] { return value }
    return nil
  }
}

// MARK: - Array Extensions

extension [SpanData] {
  var rootSpans: [SpanData] { filter(\.isRootSpan) }
  var childSpans: [SpanData] { filter(\.isChildSpan) }
  var spanNames: [String] { map(\.name) }

  func spans(named name: String) -> [SpanData] {
    filter { $0.name == name }
  }

  func contains(spanNamed name: String) -> Bool {
    spanNames.contains(name)
  }
}

extension [ReadableSpan] {
  var rootSpans: [ReadableSpan] { filter(\.isRootSpan) }
  var childSpans: [ReadableSpan] { filter(\.isChildSpan) }
  var spanNames: [String] { map(\.name) }

  func spans(named name: String) -> [ReadableSpan] {
    filter { $0.name == name }
  }

  func contains(spanNamed name: String) -> Bool {
    spanNames.contains(name)
  }
}
