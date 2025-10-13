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
import Darwin

#if canImport(UIKit) && !os(watchOS)
  import UIKit
#endif

/// Protocol for providing app launch timing data
public protocol AppLaunchProvider {
  /// The time when the app launch process began
  var coldLaunchStartTime: Date { get }

  /// The notification that signals when the cold launch process completed
  var coldLaunchEndNotification: Notification.Name { get }

  /// The notification that signals when a warm launch begins
  var warmLaunchStartNotification: Notification.Name { get }

  /// The notification that signals when a warm launch ends
  var warmLaunchEndNotification: Notification.Name { get }

  /// Threshold in seconds above which a launch is considered pre-warm
  var preWarmFallbackThreshold: TimeInterval { get }
}

/// Default implementation of AppLaunchProvider that tracks iOS app launch timing
public class DefaultAppLaunchProvider: AppLaunchProvider {
  public let coldLaunchStartTime: Date
  public let coldLaunchEndNotification: Notification.Name
  public let warmLaunchStartNotification: Notification.Name
  public let warmLaunchEndNotification: Notification.Name
  public let preWarmFallbackThreshold: TimeInterval = 30.0

  /// Shared instance for global access
  public static let shared = DefaultAppLaunchProvider()

  private init() {
    // Get actual process start time using kinfo_proc
    coldLaunchStartTime = Self.getProcessStartTime()

    #if canImport(UIKit) && !os(watchOS)
      coldLaunchEndNotification = UIApplication.didFinishLaunchingNotification
      warmLaunchStartNotification = UIApplication.willEnterForegroundNotification
      warmLaunchEndNotification = UIApplication.didBecomeActiveNotification
      AwsOpenTelemetryLogger.debug("DefaultAppLaunchProvider initialized with startTime: \(coldLaunchStartTime), coldEndNotification: \(coldLaunchEndNotification.rawValue), warmStartNotification: \(warmLaunchStartNotification.rawValue), warmEndNotification: \(warmLaunchEndNotification.rawValue)")
    #else
      // For platforms without UIKit, we can't provide meaningful app launch tracking
      fatalError("DefaultAppLaunchProvider requires UIKit for app launch notifications")
    #endif
  }

  private static func getProcessStartTime() -> Date {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

    let result = sysctl(&mib, 4, &info, &size, nil, 0)
    guard result == 0 else {
      AwsOpenTelemetryLogger.debug("Failed to get process start time, falling back to current time")
      return Date()
    }

    let startTime = info.kp_proc.p_starttime
    let timeInterval = TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1_000_000
    return Date(timeIntervalSince1970: timeInterval)
  }
}
