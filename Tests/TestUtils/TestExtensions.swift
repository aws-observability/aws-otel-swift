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
