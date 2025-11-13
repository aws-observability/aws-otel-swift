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

public class AwsDeviceKitManager {
  public static let shared = AwsDeviceKitManager()

  private let queue = DispatchQueue(label: "software.amazon.opentelemetry.devicekit")
  private let rateLimitInterval: CFAbsoluteTime = 1.0
  private let deviceKit: DeviceKitPolyfillProtocol.Type

  private var lastBatteryCheck: CFAbsoluteTime = 0
  private var lastCPUCheck: CFAbsoluteTime = 0
  private var lastMemoryCheck: CFAbsoluteTime = 0

  private var cachedBatteryLevel: Double?
  private var cachedCPUUtil: Double?
  private var cachedMemoryUsage: Double?

  init(deviceKit: DeviceKitPolyfillProtocol.Type = DeviceKitPolyfill.self) {
    self.deviceKit = deviceKit
  }

  /// Gets battery level as a percentage with rate limiting
  /// - Returns: Battery level where 0.0 = 0%, 1.0 = 100%, or nil if unavailable
  public func getBatteryLevel() -> Double? {
    return queue.sync {
      let now = CFAbsoluteTimeGetCurrent()
      if now - lastBatteryCheck >= rateLimitInterval {
        lastBatteryCheck = now
        cachedBatteryLevel = deviceKit.getBatteryLevel()
      }
      return cachedBatteryLevel
    }
  }

  /// Gets CPU utilization ratio with rate limiting
  /// - Returns: CPU utilization where 1.0 = 100% of one CPU core, or nil if unavailable
  public func getCPUUtil() -> Double? {
    return queue.sync {
      let now = CFAbsoluteTimeGetCurrent()
      if now - lastCPUCheck >= rateLimitInterval {
        lastCPUCheck = now
        cachedCPUUtil = deviceKit.getCPUUsage()
      }
      return cachedCPUUtil
    }
  }

  /// Gets memory usage in megabytes (RSS) with rate limiting
  /// - Returns: Physical memory usage in megabytes, or nil if unavailable
  public func getMemoryUsage() -> Double? {
    return queue.sync {
      let now = CFAbsoluteTimeGetCurrent()
      if now - lastMemoryCheck >= rateLimitInterval {
        lastMemoryCheck = now
        cachedMemoryUsage = deviceKit.getMemoryUsage()
      }
      return cachedMemoryUsage
    }
  }
}
