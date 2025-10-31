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
   * Test view controller that conforms to ViewControllerCustomization
   */
  class TestViewController: UIViewController, ViewControllerCustomization {
    var customScreenName: String?

    // Implement the protocol method directly, don't override
    var shouldCaptureView: Bool { return true }
  }

  /**
   * Test view controller that opts out of instrumentation
   */
  class OptOutViewController: UIViewController, ViewControllerCustomization {
    var customScreenName: String?

    // Implement the protocol method directly, don't override
    var shouldCaptureView: Bool { return false }
  }

  /**
   * Basic tests for ViewControllerHandler functionality.
   */
  final class ViewControllerHandlerTests: XCTestCase {
    var handler: ViewControllerHandler!
    var uiKitViewInstrumentation: UIKitViewInstrumentation!

    override func setUp() {
      super.setUp()
      let testBundle = Bundle(for: type(of: self))
      uiKitViewInstrumentation = UIKitViewInstrumentation(bundle: testBundle)
      handler = uiKitViewInstrumentation.handler
    }

    override func tearDown() {
      handler = nil
      uiKitViewInstrumentation = nil
      super.tearDown()
    }

    func testBasicHandlerFunctionality() {
      let viewController = TestViewController()

      // Test that handler methods can be called without crashing
      XCTAssertNoThrow(handler.onViewDidLoad(viewController))
      XCTAssertNoThrow(handler.onViewDidAppear(viewController))
    }

    func testOptOutViewController() {
      let uiKitViewInstrumentation = UIKitViewInstrumentation()

      let optOutVC = OptOutViewController()

      XCTAssertFalse(optOutVC.shouldCaptureView(using: uiKitViewInstrumentation), "OptOut view controller should be filtered")

      // Should not crash when called on filtered controllers
      XCTAssertNoThrow(handler.onViewDidLoad(optOutVC))
    }

    func testAllowedViewController() {
      let uiKitViewInstrumentation = UIKitViewInstrumentation()

      let testVC = TestViewController()

      XCTAssertTrue(testVC.shouldCaptureView(using: uiKitViewInstrumentation), "Test view controller should be captured")

      // Should not crash when called on allowed controllers
      XCTAssertNoThrow(handler.onViewDidLoad(testVC))
    }

    func testSystemViewControllerFiltering() {
      let testVC = UIViewController()

      XCTAssertFalse(testVC.shouldCaptureView(using: uiKitViewInstrumentation), "Should filter out system UIViewController")
    }
  }

#endif
