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

public protocol AppLaunchProvider {
  /// The time when the app launch began
  var coldLaunchStartTime: Date? { get }

  /// The name of the cold launch start marker. Typically, this occurs before the app is launched so the Notification API cannot help us here
  var coldStartName: String { get }

  /// The notification that signals when a warm launch begins
  var warmStartNotification: Notification.Name { get }

  /// The notification that signals when a cold or warm launch has completed
  var launchEndNotification: Notification.Name { get }

  /// Threshold above which a launch is considered pre-warm
  var preWarmFallbackThreshold: TimeInterval { get }

  // Notification after which warm launches are allowed to be reported
  var hiddenNotification: Notification.Name { get }

  /// Additional lifecycle events to record as log events
  var additionalLifecycleEvents: [Notification.Name] { get }
}

public class DefaultAppLaunchProvider: AppLaunchProvider {
  public let coldLaunchStartTime: Date?
  public let coldStartName: String
  public let warmStartNotification: Notification.Name
  public let launchEndNotification: Notification.Name
  public let hiddenNotification: Notification.Name
  public let preWarmFallbackThreshold: TimeInterval = 30.0
  public let additionalLifecycleEvents: [Notification.Name]

  public static let shared = DefaultAppLaunchProvider()

  private init() {
    coldLaunchStartTime = Self.getProcessStartTime()
    coldStartName = "kp_proc.p_starttime"

    #if canImport(UIKit) && !os(watchOS)
      warmStartNotification = UIApplication.willEnterForegroundNotification
      launchEndNotification = UIApplication.didBecomeActiveNotification
      hiddenNotification = UIApplication.didEnterBackgroundNotification
      additionalLifecycleEvents = [
        UIApplication.didFinishLaunchingNotification,
        UIApplication.didEnterBackgroundNotification,
        UIApplication.willResignActiveNotification,
        UIApplication.willTerminateNotification
      ]
    #else
      // No-op unless UIApplication notifications are available
      // (generally supported by iOS, iPadOS, Mac Catalyst, tvOS, visionOS)
      warmStartNotification = Notification.Name("noop.warm")
      launchEndNotification = Notification.Name("noop.end")
      hiddenNotification = Notification.Name("noop.hidden")
      additionalLifecycleEvents = []
    #endif
  }

  /// Retrieves the exact timestamp when this process started by querying the kernel.
  /// I certainly did not come up with this, but you can find many references of its usage in the open source community.
  static func getProcessStartTime() -> Date? {
    // Create empty container to hold process information from the kernel
    var info = kinfo_proc()

    // Tell the system how much space we've allocated for the response
    var size: Int = MemoryLayout<kinfo_proc>.size

    // Management information base command to lookup process start time
    var mib: [Int32] = [
      CTL_KERN, // Instruction to look at kernel information
      KERN_PROC, // Instruction to look at current processes
      KERN_PROC_PID, // Instruction to lookup a process ID
      getpid() // Our current process ID
    ]

    // Make the actual request to the operating system to fill in info
    let result = sysctl(
      &mib, // request_path
      4, // path_length
      &info, // response_container
      &size, // container_size
      nil, // no_input_data
      0 // input_size
    )

    // Check if the system call succeeded (0 = success, anything else = error)
    guard result == 0 else {
      AwsInternalLogger.error("Failed to get process start time")
      return nil
    }

    // The OS has now populated the entire kinfo_proc structure with process data:
    //   info.kp_proc.p_pid         - Process ID (should match getpid())
    //   info.kp_proc.p_ppid        - Parent process ID
    //   info.kp_proc.p_pgrp        - Process group ID
    //   info.kp_proc.p_uid         - User ID that owns this process
    //   info.kp_proc.p_gid         - Group ID that owns this process
    //   info.kp_proc.p_comm        - Process name (executable name)
    //   info.kp_proc.p_starttime   - When the process started (what we want)
    //   info.kp_proc.p_stat        - Process state (running, sleeping, etc.)
    //   info.kp_proc.p_nice        - Process priority/niceness
    //   info.kp_proc.p_flag        - Various process flags
    //   info.kp_eproc.e_vm         - Virtual memory info

    // But we are only interesetd in p_starttime to determine cold launch start
    let startTime = info.kp_proc.p_starttime
    let timeInterval = TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1_000_000
    return Date(timeIntervalSince1970: timeInterval)
  }
}
