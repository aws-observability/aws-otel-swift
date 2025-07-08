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

#if canImport(UIKit) && !os(watchOS)
  import UIKit
  import OpenTelemetryApi
  import OpenTelemetrySdk

  /**
   * Tests for UIViewController extensions functionality.
   * Focuses on associated objects, handler management, and bundle filtering.
   */
  final class UIViewControllerExtensionsTests: XCTestCase {
    var tracer: Tracer!

    override func setUp() {
      super.setUp()

      let tracerProvider = TracerProviderBuilder().build()
      tracer = tracerProvider.get(instrumentationName: "test")
    }

    // MARK: - InstrumentationState Tests

    func testInstrumentationStateProperty() {
      let viewController = UIViewController()

      // Initially should be nil
      XCTAssertNil(viewController.instrumentationState)

      // Set a state
      let state = ViewInstrumentationState(identifier: "test-id")
      viewController.instrumentationState = state

      // Should retrieve the same state
      XCTAssertNotNil(viewController.instrumentationState)
      XCTAssertEqual(viewController.instrumentationState?.identifier, "test-id")

      // Set to nil
      viewController.instrumentationState = nil
      XCTAssertNil(viewController.instrumentationState)
    }

    func testInstrumentationStateUniqueness() {
      let viewController1 = UIViewController()
      let viewController2 = UIViewController()

      let state1 = ViewInstrumentationState(identifier: "vc1")
      let state2 = ViewInstrumentationState(identifier: "vc2")

      viewController1.instrumentationState = state1
      viewController2.instrumentationState = state2

      // Each view controller should have its own state
      XCTAssertEqual(viewController1.instrumentationState?.identifier, "vc1")
      XCTAssertEqual(viewController2.instrumentationState?.identifier, "vc2")
      XCTAssertNotEqual(viewController1.instrumentationState?.identifier,
                        viewController2.instrumentationState?.identifier)
    }

    // MARK: - Handler Management Tests

    func testSetInstrumentationHandler() {
      let handler = ViewControllerHandler(tracer: tracer)

      // Set the handler
      UIViewController.setInstrumentationHandler(handler)

      // Create a view controller and verify it can access the handler
      let viewController = UIViewController()

      // The handler should be accessible through the static method
      // Note: We can't directly test the private static property,
      // but we can verify the handler was set by testing its effects
      XCTAssertNotNil(handler)
    }

    // MARK: - Bundle Filtering Tests

    func testShouldCaptureViewWithCustomization() {
      class TestViewController: UIViewController, ViewControllerCustomization {
        let shouldCapture: Bool

        init(shouldCapture: Bool) {
          self.shouldCapture = shouldCapture
          super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
          fatalError("init(coder:) has not been implemented")
        }

        var shouldCaptureView: Bool { shouldCapture }
      }

      let uiKitViewInstrumentation = UIKitViewInstrumentation(tracer: tracer)

      let captureVC = TestViewController(shouldCapture: true)
      let noCaptureVC = TestViewController(shouldCapture: false)

      XCTAssertTrue(captureVC.shouldCaptureView(using: uiKitViewInstrumentation))
      XCTAssertFalse(noCaptureVC.shouldCaptureView(using: uiKitViewInstrumentation))
    }

    func testBundleFiltering() {
      let testBundle = Bundle(for: type(of: self))
      let testBundleInstrumentation = UIKitViewInstrumentation(tracer: tracer, bundle: testBundle)

      let viewController = UIViewController()

      // Test that the bundle filtering mechanism works without crashing
      let result = viewController.shouldCaptureView(using: testBundleInstrumentation)

      // The result depends on bundle configuration, but should be a valid boolean
      XCTAssertTrue(result == true || result == false, "Bundle filtering should return a valid boolean")

      // Test with a view controller that has customization
      class CustomVC: UIViewController, ViewControllerCustomization {
        var shouldCaptureView: Bool { return true }
      }

      let customVC = CustomVC()
      let customResult = customVC.shouldCaptureView(using: testBundleInstrumentation)

      // Customization should override bundle filtering
      XCTAssertTrue(customResult, "ViewControllerCustomization should override bundle filtering")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentInstrumentationStateAccess() {
      let viewController = UIViewController()
      let expectation = XCTestExpectation(description: "Concurrent state access")
      expectation.expectedFulfillmentCount = 50

      // Simulate concurrent access to instrumentation state
      for i in 0 ..< 50 {
        DispatchQueue.global().async {
          let state = ViewInstrumentationState(identifier: "concurrent-\(i)")
          viewController.instrumentationState = state

          // Verify we can read it back
          let retrieved = viewController.instrumentationState
          XCTAssertNotNil(retrieved)

          expectation.fulfill()
        }
      }

      wait(for: [expectation], timeout: 5.0)

      // Final state should be one of the set states
      XCTAssertNotNil(viewController.instrumentationState)
    }
  }

#endif
