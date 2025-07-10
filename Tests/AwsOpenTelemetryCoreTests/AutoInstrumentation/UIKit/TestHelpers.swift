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
import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

public extension XCTestCase {
  /// Wait for a block to return true
  /// - Parameters:
  ///   - timeout: The longest time you are willing to wait
  ///   - interval: The interval in which to check the block
  ///   - block: A block to execute, return true when condition is met
  func wait(timeout: TimeInterval = 5.0, interval: TimeInterval = 0.1, until block: @escaping () throws -> Bool) {
    let expectation = expectation(description: "wait for block to pass")
    let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
      do {
        if try block() {
          expectation.fulfill()
        }
      } catch {
        XCTFail("Waiting for operation that threw an error: \(error)")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: timeout)
    timer.invalidate()
  }

  /// Waits the given amount of seconds
  /// - Parameter delay: Seconds to wait
  func wait(delay: TimeInterval = 1.0) {
    let expectation = XCTestExpectation()

    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: delay + 1.0)
  }
}

/**
 * Mock span processor that tracks started and ended spans for testing
 */
public class MockSpanProcessor: SpanProcessor {
  private let lock = NSLock()
  public private(set) var startedSpans: [SpanData] = []
  public private(set) var endedSpans: [SpanData] = []

  public var isStartRequired: Bool { true }
  public var isEndRequired: Bool { true }

  public init() {}

  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    lock.lock()
    defer { lock.unlock() }
    let spanData = span.toSpanData()
    startedSpans.append(spanData)
  }

  public func onEnd(span: ReadableSpan) {
    lock.lock()
    defer { lock.unlock() }
    let spanData = span.toSpanData()
    endedSpans.append(spanData)
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    // No-op for mock
  }

  public func forceFlush(timeout: TimeInterval?) {
    // No-op for mock
  }

  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    startedSpans.removeAll()
    endedSpans.removeAll()
  }

  public func getStartedSpans() -> [SpanData] {
    lock.lock()
    defer { lock.unlock() }
    return Array(startedSpans)
  }

  public func getEndedSpans() -> [SpanData] {
    lock.lock()
    defer { lock.unlock() }
    return Array(endedSpans)
  }
}
