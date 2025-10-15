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
  var coldLaunchStartTime: Date? { get }

  /// The name of the cold launch start marker. Typically, this occurs before the app is launched so the Notification API cannot help us here
  var coldStartName: String { get }

  /// The notification that signals when the cold launch process completed
  var coldEndNotification: Notification.Name { get }

  /// The notification that signals when a warm launch begins
  var warmStartNotification: Notification.Name { get }

  /// The notification that signals when a warm launch ends
  var warmEndNotification: Notification.Name { get }

  /// Threshold in seconds above which a launch is considered pre-warm
  var preWarmFallbackThreshold: TimeInterval { get }

  var hiddenNotification: Notification.Name { get }

  /// Additional lifecycle events to record as log events. By default, cold
  var additionalLifecycleEvents: [Notification.Name] { get }
}

/// Default implementation of AppLaunchProvider that tracks iOS app launch timing
public class DefaultAppLaunchProvider: AppLaunchProvider {
  public let coldLaunchStartTime: Date?
  public let coldStartName: String
  public let coldEndNotification: Notification.Name
  public let warmStartNotification: Notification.Name
  public let warmEndNotification: Notification.Name
  public let hiddenNotification: Notification.Name
  public let preWarmFallbackThreshold: TimeInterval = 30.0
  public let additionalLifecycleEvents: [Notification.Name]

  /// Shared instance for global access
  public static let shared = DefaultAppLaunchProvider()

  private init() {
    // Get actual process start time using kinfo_proc
    coldLaunchStartTime = Self.getProcessStartTime()
    coldStartName = "kp_proc.p_starttime"

    #if canImport(UIKit) && !os(watchOS)
      coldEndNotification = UIApplication.didFinishLaunchingNotification
      warmStartNotification = UIApplication.willEnterForegroundNotification
      warmEndNotification = UIApplication.didBecomeActiveNotification
      hiddenNotification = UIApplication.didEnterBackgroundNotification
      additionalLifecycleEvents = [
        UIApplication.didBecomeActiveNotification,
        UIApplication.didEnterBackgroundNotification,
        UIApplication.willEnterForegroundNotification,
        UIApplication.willResignActiveNotification,
        UIApplication.willTerminateNotification
      ]
      AwsOpenTelemetryLogger.debug("DefaultAppLaunchProvider initialized with startTime: \(coldLaunchStartTime), coldEndNotification: \(coldEndNotification.rawValue), warmStartNotification: \(warmStartNotification.rawValue), warmEndNotification: \(warmEndNotification.rawValue)")
    #else
      // For platforms without UIKit, we can't provide meaningful app launch tracking
      fatalError("DefaultAppLaunchProvider requires UIKit for app launch notifications")
    #endif
  }

  static func getProcessStartTime() -> Date? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

    let result = sysctl(&mib, 4, &info, &size, nil, 0)
    guard result == 0 else {
      AwsOpenTelemetryLogger.debug("Failed to get process start time")
      return nil
    }

    let startTime = info.kp_proc.p_starttime
    let timeInterval = TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1_000_000
    return Date(timeIntervalSince1970: timeInterval)
  }
}
