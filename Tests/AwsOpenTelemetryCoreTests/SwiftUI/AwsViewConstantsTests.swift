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

final class AwsViewConstantsTests: XCTestCase {
  func testSwiftUISpanNames() {
    XCTAssertEqual(AwsViewConstants.spanNameView, "view")
    XCTAssertEqual(AwsViewConstants.spanNameBody, "body")
    XCTAssertEqual(AwsViewConstants.TimeToFirstAppear, "TimeToFirstAppear")
    XCTAssertEqual(AwsViewConstants.spanNameOnAppear, "onAppear")
    XCTAssertEqual(AwsViewConstants.spanNameOnDisappear, "onDisappear")
  }

  func testUIKitSpanNames() {
    XCTAssertEqual(AwsViewConstants.spanNameTimeOnScreen, "TimeOnScreen")
    XCTAssertEqual(AwsViewConstants.spanNameViewDidLoad, "viewDidLoad")
    XCTAssertEqual(AwsViewConstants.spanNameViewWillAppear, "viewWillAppear")
    XCTAssertEqual(AwsViewConstants.spanNameViewIsAppearing, "viewIsAppearing")
    XCTAssertEqual(AwsViewConstants.spanNameViewDidAppear, "viewDidAppear")
  }

  func testAttributeKeys() {
    XCTAssertEqual(AwsViewConstants.attributeScreenName, "screen.name")
    XCTAssertEqual(AwsViewConstants.attributeViewType, "view.type")
    XCTAssertEqual(AwsViewConstants.attributeViewLifecycle, "view.lifecycle")
    XCTAssertEqual(AwsViewConstants.attributeViewBodyCount, "view.body.count")
    XCTAssertEqual(AwsViewConstants.attributeViewAppearCount, "view.appear.count")
    XCTAssertEqual(AwsViewConstants.attributeViewDisappearCount, "view.disappear.count")
    XCTAssertEqual(AwsViewConstants.attributeViewClass, "view.class")
  }

  func testAttributeValues() {
    XCTAssertEqual(AwsViewConstants.valueSwiftUI, "swiftui")
    XCTAssertEqual(AwsViewConstants.valueBody, "body")
    XCTAssertEqual(AwsViewConstants.valueOnAppear, "onAppear")
    XCTAssertEqual(AwsViewConstants.valueOnDisappear, "onDisappear")
  }

  func testStatusDescriptions() {
    XCTAssertEqual(AwsViewConstants.statusAppBackgrounded, "app_backgrounded")
    XCTAssertEqual(AwsViewConstants.statusViewDisappeared, "view_disappeared")
  }
}
