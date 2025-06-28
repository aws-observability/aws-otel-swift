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
@testable import AwsOpenTelemetryUIKitInstrumentation

/**
 * Tests for ThreadSafe property wrapper functionality.
 * These tests can run on any platform since ThreadSafe doesn't depend on UIKit.
 */
final class ThreadSafeTests: XCTestCase {
  func testBasicReadWrite() {
    let threadSafeValue = ThreadSafe<Int>(wrappedValue: 0)

    threadSafeValue.wrappedValue = 42
    XCTAssertEqual(threadSafeValue.wrappedValue, 42)

    threadSafeValue.wrappedValue = 100
    XCTAssertEqual(threadSafeValue.wrappedValue, 100)
  }

  func testConcurrentReads() {
    let threadSafeValue = ThreadSafe<String>(wrappedValue: "initial")
    let expectation = XCTestExpectation(description: "Concurrent reads")
    expectation.expectedFulfillmentCount = 100

    // Simulate concurrent reads
    for _ in 0 ..< 100 {
      DispatchQueue.global().async {
        let value = threadSafeValue.wrappedValue
        XCTAssertEqual(value, "initial")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testConcurrentWrites() {
    let threadSafeCounter = ThreadSafe<Int>(wrappedValue: 0)
    let expectation = XCTestExpectation(description: "Concurrent writes")
    expectation.expectedFulfillmentCount = 100

    // Simulate concurrent writes
    for i in 0 ..< 100 {
      DispatchQueue.global().async {
        threadSafeCounter.wrappedValue = i
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Final value should be one of the written values
    let finalValue = threadSafeCounter.wrappedValue
    XCTAssertGreaterThanOrEqual(finalValue, 0)
    XCTAssertLessThan(finalValue, 100)
  }

  func testMixedReadWrite() {
    let threadSafeArray = ThreadSafe<[String]>(wrappedValue: [])
    let expectation = XCTestExpectation(description: "Mixed read/write")
    expectation.expectedFulfillmentCount = 200

    // Simulate concurrent reads and writes
    for i in 0 ..< 100 {
      // Write operation
      DispatchQueue.global().async {
        var currentArray = threadSafeArray.wrappedValue
        currentArray.append("item\(i)")
        threadSafeArray.wrappedValue = currentArray
        expectation.fulfill()
      }

      // Read operation
      DispatchQueue.global().async {
        let count = threadSafeArray.wrappedValue.count
        XCTAssertGreaterThanOrEqual(count, 0)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Final array should have some items (exact count may vary due to race conditions)
    let finalCount = threadSafeArray.wrappedValue.count
    XCTAssertGreaterThanOrEqual(finalCount, 0)
    XCTAssertLessThanOrEqual(finalCount, 100)
  }

  func testComplexDataStructure() {
    struct TestData {
      var counter: Int = 0
      var items: [String] = []
      var metadata: [String: Any] = [:]
    }

    let threadSafeData = ThreadSafe<TestData>(wrappedValue: TestData())

    var data = threadSafeData.wrappedValue
    data.counter = 10
    data.items = ["a", "b", "c"]
    data.metadata["key"] = "value"
    threadSafeData.wrappedValue = data

    let result = threadSafeData.wrappedValue
    XCTAssertEqual(result.counter, 10)
    XCTAssertEqual(result.items.count, 3)
    XCTAssertEqual(result.metadata["key"] as? String, "value")
  }
}
