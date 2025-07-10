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

/**
 * Tests for ViewInstrumentationState functionality.
 * These tests can run on any platform since ViewInstrumentationState doesn't depend on UIKit.
 */
final class ViewInstrumentationStateTests: XCTestCase {
  func testInitialState() {
    let state = ViewInstrumentationState()
    XCTAssertNil(state.identifier)
    XCTAssertFalse(state.viewDidLoadSpanCreated)
    XCTAssertFalse(state.viewWillAppearSpanCreated)
    XCTAssertFalse(state.viewIsAppearingSpanCreated)
    XCTAssertFalse(state.viewDidAppearSpanCreated)
  }

  func testInitWithIdentifier() {
    let identifier = "test-identifier"
    let state = ViewInstrumentationState(identifier: identifier)

    XCTAssertEqual(state.identifier, identifier)
    XCTAssertFalse(state.viewDidLoadSpanCreated)
    XCTAssertFalse(state.viewWillAppearSpanCreated)
    XCTAssertFalse(state.viewIsAppearingSpanCreated)
    XCTAssertFalse(state.viewDidAppearSpanCreated)
  }

  func testSpanCreationFlags() {
    let state = ViewInstrumentationState()

    // Test setting flags
    state.viewDidLoadSpanCreated = true
    XCTAssertTrue(state.viewDidLoadSpanCreated)

    state.viewWillAppearSpanCreated = true
    XCTAssertTrue(state.viewWillAppearSpanCreated)

    state.viewIsAppearingSpanCreated = true
    XCTAssertTrue(state.viewIsAppearingSpanCreated)

    state.viewDidAppearSpanCreated = true
    XCTAssertTrue(state.viewDidAppearSpanCreated)

    state.viewDidDisappearSpanCreated = true
    XCTAssertTrue(state.viewDidDisappearSpanCreated)
  }
}
