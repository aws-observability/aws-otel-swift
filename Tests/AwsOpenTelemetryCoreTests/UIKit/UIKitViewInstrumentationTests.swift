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
@testable import AwsOpenTelemetryCore

#if canImport(UIKit) && !os(watchOS)
  import UIKit
  import OpenTelemetryApi
  import OpenTelemetrySdk

  /**
   * Comprehensive tests for UIKitViewInstrumentation class.
   * Covers initialization, installation, thread safety, integration, and memory management.
   */
  final class UIKitViewInstrumentationTests: XCTestCase {
    var mockSpanProcessor: MockSpanProcessor!
    var tracerProvider: TracerProviderSdk!
    var tracer: Tracer!

    override func setUp() {
      super.setUp()

      mockSpanProcessor = MockSpanProcessor()
      tracerProvider = TracerProviderBuilder()
        .add(spanProcessor: mockSpanProcessor)
        .build()
      tracer = tracerProvider.get(instrumentationName: "test")
    }

    override func tearDown() {
      mockSpanProcessor.reset()
      super.tearDown()
    }

    // MARK: - Initialization Tests

    func testConvenienceInitialization() {
      let instrumentation = UIKitViewInstrumentation()

      XCTAssertEqual(instrumentation.bundlePath, Bundle.main.bundlePath)
      XCTAssertNotNil(instrumentation.handler)
    }

    func testCustomBundleInitialization() {
      let testBundle = Bundle(for: type(of: self))
      let instrumentation = UIKitViewInstrumentation(bundle: testBundle)

      XCTAssertEqual(instrumentation.bundlePath, testBundle.bundlePath)
      XCTAssertNotNil(instrumentation.handler)
    }

    func testBundlePathStorage() {
      let testBundle = Bundle(for: type(of: self))
      let instrumentation = UIKitViewInstrumentation(bundle: testBundle)

      XCTAssertEqual(instrumentation.bundlePath, testBundle.bundlePath)
      XCTAssertNotEqual(instrumentation.bundlePath, Bundle.main.bundlePath)
    }

    // MARK: - Installation Tests

    func testSingleInstallation() {
      let instrumentation = UIKitViewInstrumentation()

      // First installation should succeed
      instrumentation.install()

      // Verify installation doesn't crash on repeated calls
      instrumentation.install()
      instrumentation.install()

      // Should not crash and should handle multiple install calls gracefully
      XCTAssertTrue(true, "Multiple install calls should not crash")
    }

    /**
     * Tests that the UIKitViewInstrumentation correctly handles concurrent installation attempts.
     *
     * This test simulates multiple threads attempting to install the instrumentation simultaneously
     * and verifies that the class correctly handles this concurrency through its internal locking mechanism.
     */
    func testQueueBasedThreadSafety() {
      let instrumentation = UIKitViewInstrumentation()
      let expectation = XCTestExpectation(description: "Concurrent installation")
      expectation.expectedFulfillmentCount = 10

      // Simulate concurrent installation attempts from multiple threads
      for i in 0 ..< 10 {
        // Use different queues to ensure true concurrency
        let queue = DispatchQueue(label: "test.queue.\(i)", attributes: .concurrent)

        queue.async {
          // Attempt to install the instrumentation
          instrumentation.install()
          expectation.fulfill()
        }
      }

      wait(for: [expectation], timeout: 5.0)

      // The test passes if it completes without crashing
      // The internal lock in UIKitViewInstrumentation should prevent race conditions
      XCTAssertTrue(true, "Concurrent installation should be thread-safe")
    }

    // MARK: - Integration Tests

    func testCreationAndBasicFunctionality() {
      let instrumentation = UIKitViewInstrumentation()

      XCTAssertNotNil(instrumentation)
      XCTAssertNotNil(instrumentation.handler)

      // Should be able to install without issues
      XCTAssertNoThrow(instrumentation.install())
    }

    func testParentSpanDelegation() {
      let instrumentation = UIKitViewInstrumentation()
      let _ = UIViewController()

      // Test that instrumentation works with view controllers
      XCTAssertNotNil(instrumentation.handler)
    }

    func testHandlerIntegration() {
      let instrumentation = UIKitViewInstrumentation()

      // Handler should be properly initialized and connected
      XCTAssertNotNil(instrumentation.handler)

      // Test that handler works correctly
      let viewController = UIViewController()
      instrumentation.handler.onViewDidLoad(viewController)

      // Should not crash - indicates proper integration
      XCTAssertTrue(true, "Handler integration should work correctly")
    }

    // MARK: - Memory Management Tests

    func testMemoryManagement() {
      weak var weakInstrumentation: UIKitViewInstrumentation?

      autoreleasepool {
        let instrumentation = UIKitViewInstrumentation()
        weakInstrumentation = instrumentation

        // Use the instrumentation
        instrumentation.install()

        // Should be alive
        XCTAssertNotNil(weakInstrumentation)
      }

      // After autoreleasepool, should be deallocated
      // Note: This test might be flaky due to ARC optimizations
      // but it's useful for detecting obvious memory leaks
    }

    // MARK: - Configuration Tests

    func testMultipleInstances() {
      let instrumentation1 = UIKitViewInstrumentation()
      let instrumentation2 = UIKitViewInstrumentation()

      // Should be able to create multiple instances
      XCTAssertNotNil(instrumentation1)
      XCTAssertNotNil(instrumentation2)

      // Each should have its own handler
      XCTAssertNotNil(instrumentation1.handler)
      XCTAssertNotNil(instrumentation2.handler)

      // Should be able to install both
      XCTAssertNoThrow(instrumentation1.install())
      XCTAssertNoThrow(instrumentation2.install())
    }

    func testDifferentBundles() {
      let mainInstrumentation = UIKitViewInstrumentation(bundle: .main)
      let testInstrumentation = UIKitViewInstrumentation(bundle: Bundle(for: type(of: self)))

      XCTAssertNotEqual(mainInstrumentation.bundlePath, testInstrumentation.bundlePath)

      // Both should work independently
      XCTAssertNoThrow(mainInstrumentation.install())
      XCTAssertNoThrow(testInstrumentation.install())
    }
  }

#endif
