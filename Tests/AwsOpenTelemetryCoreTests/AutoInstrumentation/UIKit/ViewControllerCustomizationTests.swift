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

  /**
   * Tests for ViewControllerCustomization protocol functionality.
   */
  final class ViewControllerCustomizationTests: XCTestCase {
    // MARK: - Test View Controllers

    class DefaultViewController: UIViewController, ViewControllerCustomization {
      // Uses default implementations
    }

    class CustomNameViewController: UIViewController, ViewControllerCustomization {
      var customViewName: String? { return "MyCustomName" }
    }

    class OptOutViewController: UIViewController, ViewControllerCustomization {
      var shouldCaptureView: Bool { return false }
    }

    class FullyCustomViewController: UIViewController, ViewControllerCustomization {
      var customViewName: String? { return "FullyCustom" }
      var shouldCaptureView: Bool { return true }
    }

    // MARK: - Tests

    func testDefaultImplementations() {
      let viewController = DefaultViewController()

      // Test default implementations
      XCTAssertNil(viewController.customViewName, "Default customViewName should be nil")
      XCTAssertTrue(viewController.shouldCaptureView, "Default shouldCaptureView should be true")
    }

    func testCustomViewName() {
      let viewController = CustomNameViewController()

      XCTAssertEqual(viewController.customViewName, "MyCustomName")
      XCTAssertTrue(viewController.shouldCaptureView, "Should use default shouldCaptureView")
    }

    func testOptOutBehavior() {
      let viewController = OptOutViewController()

      XCTAssertNil(viewController.customViewName, "Should use default customViewName")
      XCTAssertFalse(viewController.shouldCaptureView, "Should opt out of capture")
    }

    func testFullyCustomBehavior() {
      let viewController = FullyCustomViewController()

      XCTAssertEqual(viewController.customViewName, "FullyCustom")
      XCTAssertTrue(viewController.shouldCaptureView)
    }

    func testProtocolConformance() {
      // Test that regular UIViewController can conform to the protocol
      class TestVC: UIViewController, ViewControllerCustomization {}

      let viewController = TestVC()

      // Should compile and use default implementations
      XCTAssertNil(viewController.customViewName)
      XCTAssertTrue(viewController.shouldCaptureView)
    }

    func testMultipleViewControllers() {
      let controllers: [UIViewController & ViewControllerCustomization] = [
        DefaultViewController(),
        CustomNameViewController(),
        OptOutViewController(),
        FullyCustomViewController()
      ]

      let customNames = controllers.map { $0.customViewName }
      let shouldCapture = controllers.map { $0.shouldCaptureView }

      XCTAssertEqual(customNames, [nil, "MyCustomName", nil, "FullyCustom"])
      XCTAssertEqual(shouldCapture, [true, true, false, true])
    }
  }

#endif
