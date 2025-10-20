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

/// Constants used by view instrumentation for span names and attributes
public enum AwsViewConstants {
  // Common
  public static let TimeToFirstAppear = "TimeToFirstAppear"
  public static let attributeScreenName = "screen.name"
  public static let attributeViewType = "view.type"
  public static let spanNameTimeOnScreen = "TimeOnScreen"

  // SwiftUI
  public static let valueSwiftUI = "swiftui"
  public static let spanNameView = "view"
  public static let spanNameBody = "body"
  public static let valueBody = "body"
  public static let spanNameOnAppear = "onAppear"
  public static let valueOnAppear = "onAppear"
  public static let spanNameOnDisappear = "onDisappear"
  public static let valueOnDisappear = "onDisappear"
  public static let attributeViewLifecycle = "view.lifecycle"
  public static let attributeViewBodyCount = "view.body.count"
  public static let attributeViewAppearCount = "view.appear.count"
  public static let attributeViewDisappearCount = "view.disappear.count"

  // UIKit
  public static let valueUIKit = "uikit"
  public static let spanNameViewDidLoad = "ViewDidLoad"
  public static let spanNameViewWillAppear = "ViewWillAppear"
  public static let spanNameViewIsAppearing = "ViewIsAppearing"
  public static let spanNameViewDidAppear = "ViewDidAppear"
  public static let attributeViewClass = "view.class"
  public static let statusAppBackgrounded = "app_backgrounded"
  public static let statusViewDisappeared = "view_disappeared"
}
