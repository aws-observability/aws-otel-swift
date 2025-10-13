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
@testable import AwsOpenTelemetryCore

public class MockAppLaunchProvider: AppLaunchProvider {
  public let coldLaunchStartTime: Date
  public let coldLaunchEndNotification: Notification.Name
  public let warmLaunchStartNotification: Notification.Name
  public let warmLaunchEndNotification: Notification.Name
  public let preWarmFallbackThreshold: TimeInterval

  public init(coldLaunchStartTime: Date = Date(timeIntervalSinceNow: -1),
              coldLaunchEndNotification: Notification.Name = Notification.Name("test.coldEnd"),
              warmLaunchStartNotification: Notification.Name = Notification.Name("test.warmStart"),
              warmLaunchEndNotification: Notification.Name = Notification.Name("test.warmEnd"),
              preWarmFallbackThreshold: TimeInterval = 30.0) {
    self.coldLaunchStartTime = coldLaunchStartTime
    self.coldLaunchEndNotification = coldLaunchEndNotification
    self.warmLaunchStartNotification = warmLaunchStartNotification
    self.warmLaunchEndNotification = warmLaunchEndNotification
    self.preWarmFallbackThreshold = preWarmFallbackThreshold
  }
}
