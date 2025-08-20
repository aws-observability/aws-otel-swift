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

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class SwiftUIInstrumentationTests: XCTestCase {
  override func setUp() {
    super.setUp()
    SwiftUIInstrumentation.shared.reset()
  }

  override func tearDown() {
    SwiftUIInstrumentation.shared.reset()
    super.tearDown()
  }

  // MARK: - Initialization Tests

  func testSingletonPattern() {
    // Given & When
    let instance1 = SwiftUIInstrumentation.shared
    let instance2 = SwiftUIInstrumentation.shared

    // Then
    XCTAssertTrue(instance1 === instance2, "Should return the same singleton instance")
  }

  func testDefaultState() {
    // Given & When
    let instrumentation = SwiftUIInstrumentation.shared

    // Then
    XCTAssertFalse(instrumentation.isInstrumentationEnabled, "Should be disabled by default")
  }

  func testInitializeWithEnabledConfig() {
    // Given
    let config = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)

    // When
    SwiftUIInstrumentation.shared.initialize(with: config)

    // Then
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled)
  }

  func testInitializeWithDisabledConfig() {
    // Given
    let config = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false)

    // When
    SwiftUIInstrumentation.shared.initialize(with: config)

    // Then
    XCTAssertFalse(SwiftUIInstrumentation.shared.isInstrumentationEnabled)
  }

  func testMultipleInitializationCalls() {
    // Given
    let enabledConfig = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
    let disabledConfig = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false)

    // When
    SwiftUIInstrumentation.shared.initialize(with: enabledConfig)
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled)

    SwiftUIInstrumentation.shared.initialize(with: disabledConfig)

    // Then
    XCTAssertFalse(SwiftUIInstrumentation.shared.isInstrumentationEnabled, "Should update state on subsequent calls")
  }

  func testReset() {
    // Given
    let config = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
    SwiftUIInstrumentation.shared.initialize(with: config)
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled)

    // When
    SwiftUIInstrumentation.shared.reset()

    // Then
    XCTAssertFalse(SwiftUIInstrumentation.shared.isInstrumentationEnabled, "Should reset to disabled state")
  }

  // MARK: - Thread Safety Tests

  func testConcurrentAccess() {
    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 10

    let queue = DispatchQueue.global(qos: .userInitiated)

    // When - Multiple threads accessing simultaneously
    for i in 0 ..< 10 {
      queue.async {
        let config = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: i % 2 == 0)
        SwiftUIInstrumentation.shared.initialize(with: config)

        // Just accessing the property should be thread-safe
        _ = SwiftUIInstrumentation.shared.isInstrumentationEnabled

        expectation.fulfill()
      }
    }

    // Then
    wait(for: [expectation], timeout: 5.0)

    // Should not crash and should have a valid state
    let finalState = SwiftUIInstrumentation.shared.isInstrumentationEnabled
    XCTAssertTrue(finalState == true || finalState == false, "Should have a valid boolean state")
  }

  // MARK: - Integration with TelemetryConfig Tests

  func testWithDefaultTelemetryConfig() {
    // Given
    let defaultConfig = TelemetryConfig() // Default should be enabled

    // When
    SwiftUIInstrumentation.shared.initialize(with: defaultConfig)

    // Then
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled, "Default TelemetryConfig should enable SwiftUI instrumentation")
  }

  func testStateConsistency() {
    // Given
    let configs = [
      TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true),
      TelemetryConfig(isSwiftUIViewInstrumentationEnabled: false),
      TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
    ]

    // When & Then
    for (index, config) in configs.enumerated() {
      SwiftUIInstrumentation.shared.initialize(with: config)
      let expectedState = config.isSwiftUIViewInstrumentationEnabled
      let actualState = SwiftUIInstrumentation.shared.isInstrumentationEnabled

      XCTAssertEqual(actualState, expectedState, "State should match config at index \(index)")
    }
  }

  // MARK: - Memory Management Tests

  func testMemoryRetention() {
    // Given
    weak var weakConfig: TelemetryConfig?

    // When
    autoreleasepool {
      let config = TelemetryConfig(isSwiftUIViewInstrumentationEnabled: true)
      weakConfig = config
      SwiftUIInstrumentation.shared.initialize(with: config)
    }

    // Then
    XCTAssertNil(weakConfig, "SwiftUIInstrumentation should not retain the config object")
    XCTAssertTrue(SwiftUIInstrumentation.shared.isInstrumentationEnabled, "But should retain the configuration value")
  }
}
