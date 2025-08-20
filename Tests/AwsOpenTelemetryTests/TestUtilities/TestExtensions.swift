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

// MARK: - Test Extensions for ReadableSpan

extension ReadableSpan {
  /// Convenience property to access span attributes for testing
  var testAttributes: [String: AttributeValue] {
    return toSpanData().attributes
  }

  /// Convenience property to access parent span ID for testing
  var testParentSpanId: SpanId? {
    return toSpanData().parentSpanId
  }

  /// Convenience property to access span ID for testing
  var testSpanId: SpanId {
    return toSpanData().spanId
  }

  /// Convenience property to access trace ID for testing
  var testTraceId: TraceId {
    return toSpanData().traceId
  }

  /// Convenience property to access span status for testing
  var testStatus: Status {
    return toSpanData().status
  }

  /// Convenience property to access span kind for testing
  var testKind: SpanKind {
    return toSpanData().kind
  }

  /// Convenience property to access start time for testing
  var testStartTime: Date {
    return toSpanData().startTime
  }

  /// Convenience property to access end time for testing
  var testEndTime: Date {
    return toSpanData().endTime
  }

  /// Check if this span is a root span (no parent)
  var isRootSpan: Bool {
    return testParentSpanId == nil
  }

  /// Check if this span is a child span (has parent)
  var isChildSpan: Bool {
    return testParentSpanId != nil
  }

  /// Get attribute value as string for testing
  func getAttributeString(_ key: String) -> String? {
    return testAttributes[key]?.description
  }

  /// Get attribute value as int for testing
  func getAttributeInt(_ key: String) -> Int? {
    if case let .int(value) = testAttributes[key] {
      return value
    }
    return nil
  }

  /// Get attribute value as bool for testing
  func getAttributeBool(_ key: String) -> Bool? {
    if case let .bool(value) = testAttributes[key] {
      return value
    }
    return nil
  }
}

// MARK: - Test Extensions for Array of ReadableSpan

extension [ReadableSpan] {
  /// Filter spans by name
  func spans(named name: String) -> [ReadableSpan] {
    return filter { $0.name == name }
  }

  /// Filter root spans (no parent)
  var rootSpans: [ReadableSpan] {
    return filter(\.isRootSpan)
  }

  /// Filter child spans (have parent)
  var childSpans: [ReadableSpan] {
    return filter(\.isChildSpan)
  }

  /// Filter spans by parent span ID
  func children(of parentSpanId: SpanId) -> [ReadableSpan] {
    return filter { $0.testParentSpanId == parentSpanId }
  }

  /// Filter spans by trace ID
  func spans(inTrace traceId: TraceId) -> [ReadableSpan] {
    return filter { $0.testTraceId == traceId }
  }

  /// Get all span names
  var spanNames: [String] {
    return map(\.name)
  }

  /// Check if contains span with name
  func contains(spanNamed name: String) -> Bool {
    return spanNames.contains(name)
  }

  /// Get spans that contain a substring in their name
  func spans(containing substring: String) -> [ReadableSpan] {
    return filter { $0.name.contains(substring) }
  }
}
