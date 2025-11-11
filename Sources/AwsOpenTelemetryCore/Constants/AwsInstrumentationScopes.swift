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

import Foundation

public enum AwsInstrumentationScopes {
  public static let APP_START = "software.amazon.opentelemetry.appstart"
  public static let SESSION = "software.amazon.opentelemetry.session"
  public static let UIKIT_VIEW = "software.amazon.opentelemetry.uikit"
  public static let SWIFTUI_VIEW = "software.amazon.opentelemetry.swiftui"
  public static let HANG = "software.amazon.opentelemetry.hang"
  public static let KSCRASH = "software.amazon.opentelemetry.kscrash"
}
