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

/// Mock span processor for testing purposes
public class MockSpanProcessor: SpanProcessor {
  public private(set) var endedSpans: [ReadableSpan] = []
  public private(set) var startedSpans: [ReadableSpan] = []
  private let lock = NSLock()

  public init() {}

  public var isStartRequired: Bool { false }
  public var isEndRequired: Bool { true }

  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    lock.lock()
    defer { lock.unlock() }
    startedSpans.append(span)
  }

  public func onEnd(span: ReadableSpan) {
    lock.lock()
    defer { lock.unlock() }
    endedSpans.append(span)
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    // No-op
  }

  public func forceFlush(timeout: TimeInterval?) {
    // No-op
  }

  /// Reset the processor state for clean testing
  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    endedSpans.removeAll()
    startedSpans.removeAll()
  }

  /// Get a thread-safe copy of ended spans
  public func getEndedSpans() -> [ReadableSpan] {
    lock.lock()
    defer { lock.unlock() }
    return Array(endedSpans)
  }

  /// Get a thread-safe copy of started spans
  public func getStartedSpans() -> [ReadableSpan] {
    lock.lock()
    defer { lock.unlock() }
    return Array(startedSpans)
  }
}
