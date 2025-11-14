/*
 * Copyright (c) 2015 Dennis Weissmann
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
#if canImport(UIKit) && os(iOS)
  import UIKit
#endif

public protocol DeviceKitPolyfillProtocol {
  static func getBatteryLevel() -> Double?
  static func getCPUUsage() -> Double?
  static func getMemoryUsage() -> Double?
  static func getDeviceName() -> String
}

/**
 * Minimal polyfill for DeviceKit functionality to get device names.
 * Based on DeviceKit by Dennis Weissmann.
 */
public class DeviceKitPolyfill: DeviceKitPolyfillProtocol {
  private static func roundValue(_ value: Double, precision: Double = 1000) -> Double {
    return (value * precision).rounded() / precision
  }

  /// Gets the device identifier from the system, such as "iPhone17,2"
  private static var identifier: String = {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)

    let identifier = mirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
  }()

  /// Maps device identifier to human-readable device name
  static func mapToDevice(identifier: String) -> String {
    #if os(iOS)
      switch identifier {
      case "iPod5,1": return "iPod touch (5th generation)"
      case "iPod7,1": return "iPod touch (6th generation)"
      case "iPod9,1": return "iPod touch (7th generation)"
      case "iPhone3,1", "iPhone3,2", "iPhone3,3": return "iPhone 4"
      case "iPhone4,1": return "iPhone 4s"
      case "iPhone5,1", "iPhone5,2": return "iPhone 5"
      case "iPhone5,3", "iPhone5,4": return "iPhone 5c"
      case "iPhone6,1", "iPhone6,2": return "iPhone 5s"
      case "iPhone7,2": return "iPhone 6"
      case "iPhone7,1": return "iPhone 6 Plus"
      case "iPhone8,1": return "iPhone 6s"
      case "iPhone8,2": return "iPhone 6s Plus"
      case "iPhone9,1", "iPhone9,3": return "iPhone 7"
      case "iPhone9,2", "iPhone9,4": return "iPhone 7 Plus"
      case "iPhone8,4": return "iPhone SE"
      case "iPhone10,1", "iPhone10,4": return "iPhone 8"
      case "iPhone10,2", "iPhone10,5": return "iPhone 8 Plus"
      case "iPhone10,3", "iPhone10,6": return "iPhone X"
      case "iPhone11,2": return "iPhone XS"
      case "iPhone11,4", "iPhone11,6": return "iPhone XS Max"
      case "iPhone11,8": return "iPhone XR"
      case "iPhone12,1": return "iPhone 11"
      case "iPhone12,3": return "iPhone 11 Pro"
      case "iPhone12,5": return "iPhone 11 Pro Max"
      case "iPhone12,8": return "iPhone SE (2nd generation)"
      case "iPhone13,2": return "iPhone 12"
      case "iPhone13,1": return "iPhone 12 mini"
      case "iPhone13,3": return "iPhone 12 Pro"
      case "iPhone13,4": return "iPhone 12 Pro Max"
      case "iPhone14,5": return "iPhone 13"
      case "iPhone14,4": return "iPhone 13 mini"
      case "iPhone14,2": return "iPhone 13 Pro"
      case "iPhone14,3": return "iPhone 13 Pro Max"
      case "iPhone14,6": return "iPhone SE (3rd generation)"
      case "iPhone14,7": return "iPhone 14"
      case "iPhone14,8": return "iPhone 14 Plus"
      case "iPhone15,2": return "iPhone 14 Pro"
      case "iPhone15,3": return "iPhone 14 Pro Max"
      case "iPhone15,4": return "iPhone 15"
      case "iPhone15,5": return "iPhone 15 Plus"
      case "iPhone16,1": return "iPhone 15 Pro"
      case "iPhone16,2": return "iPhone 15 Pro Max"
      case "iPhone17,3": return "iPhone 16"
      case "iPhone17,4": return "iPhone 16 Plus"
      case "iPhone17,1": return "iPhone 16 Pro"
      case "iPhone17,2": return "iPhone 16 Pro Max"
      case "iPhone17,5": return "iPhone 16e"
      case "iPhone18,3": return "iPhone 17"
      case "iPhone18,1": return "iPhone 17 Pro"
      case "iPhone18,2": return "iPhone 17 Pro Max"
      case "iPhone18,4": return "iPhone Air"
      case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4": return "iPad 2"
      case "iPad3,1", "iPad3,2", "iPad3,3": return "iPad (3rd generation)"
      case "iPad3,4", "iPad3,5", "iPad3,6": return "iPad (4th generation)"
      case "iPad4,1", "iPad4,2", "iPad4,3": return "iPad Air"
      case "iPad5,3", "iPad5,4": return "iPad Air 2"
      case "iPad6,11", "iPad6,12": return "iPad (5th generation)"
      case "iPad7,5", "iPad7,6": return "iPad (6th generation)"
      case "iPad11,3", "iPad11,4": return "iPad Air (3rd generation)"
      case "iPad7,11", "iPad7,12": return "iPad (7th generation)"
      case "iPad11,6", "iPad11,7": return "iPad (8th generation)"
      case "iPad12,1", "iPad12,2": return "iPad (9th generation)"
      case "iPad13,18", "iPad13,19": return "iPad (10th generation)"
      case "iPad15,7", "iPad15,8": return "iPad (A16)"
      case "iPad13,1", "iPad13,2": return "iPad Air (4th generation)"
      case "iPad13,16", "iPad13,17": return "iPad Air (5th generation)"
      case "iPad14,8", "iPad14,9": return "iPad Air (11-inch) (M2)"
      case "iPad14,10", "iPad14,11": return "iPad Air (13-inch) (M2)"
      case "iPad15,3", "iPad15,4": return "iPad Air (11-inch) (M3)"
      case "iPad15,5", "iPad15,6": return "iPad Air (13-inch) (M3)"
      case "iPad2,5", "iPad2,6", "iPad2,7": return "iPad Mini"
      case "iPad4,4", "iPad4,5", "iPad4,6": return "iPad Mini 2"
      case "iPad4,7", "iPad4,8", "iPad4,9": return "iPad Mini 3"
      case "iPad5,1", "iPad5,2": return "iPad Mini 4"
      case "iPad11,1", "iPad11,2": return "iPad Mini (5th generation)"
      case "iPad14,1", "iPad14,2": return "iPad Mini (6th generation)"
      case "iPad16,1", "iPad16,2": return "iPad Mini (A17 Pro)"
      case "iPad6,3", "iPad6,4": return "iPad Pro (9.7-inch)"
      case "iPad6,7", "iPad6,8": return "iPad Pro (12.9-inch)"
      case "iPad7,1", "iPad7,2": return "iPad Pro (12.9-inch) (2nd generation)"
      case "iPad7,3", "iPad7,4": return "iPad Pro (10.5-inch)"
      case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro (11-inch)"
      case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro (12.9-inch) (3rd generation)"
      case "iPad8,9", "iPad8,10": return "iPad Pro (11-inch) (2nd generation)"
      case "iPad8,11", "iPad8,12": return "iPad Pro (12.9-inch) (4th generation)"
      case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro (11-inch) (3rd generation)"
      case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro (12.9-inch) (5th generation)"
      case "iPad14,3", "iPad14,4": return "iPad Pro (11-inch) (4th generation)"
      case "iPad14,5", "iPad14,6": return "iPad Pro (12.9-inch) (6th generation)"
      case "iPad16,3", "iPad16,4": return "iPad Pro (11-inch) (M4)"
      case "iPad16,5", "iPad16,6": return "iPad Pro (13-inch) (M4)"
      case "i386", "x86_64", "arm64": return simulator(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))
      default: return unknown(identifier)
      }
    #elseif os(tvOS)
      switch identifier {
      case "AppleTV5,3": return "Apple TV HD"
      case "AppleTV6,2": return "Apple TV 4K"
      case "AppleTV11,1": return "Apple TV 4K (2nd generation)"
      case "AppleTV14,1": return "Apple TV 4K (3rd generation)"
      case "i386", "x86_64", "arm64": return simulator(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "tvOS"))
      default: return unknown(identifier)
      }
    #elseif os(watchOS)
      switch identifier {
      case "Watch1,1": return "Apple Watch (1st generation) 38mm"
      case "Watch1,2": return "Apple Watch (1st generation) 42mm"
      case "Watch2,6": return "Apple Watch Series 1 38mm"
      case "Watch2,7": return "Apple Watch Series 1 42mm"
      case "Watch2,3": return "Apple Watch Series 2 38mm"
      case "Watch2,4": return "Apple Watch Series 2 42mm"
      case "Watch3,1", "Watch3,3": return "Apple Watch Series 3 38mm"
      case "Watch3,2", "Watch3,4": return "Apple Watch Series 3 42mm"
      case "Watch4,1", "Watch4,3": return "Apple Watch Series 4 40mm"
      case "Watch4,2", "Watch4,4": return "Apple Watch Series 4 44mm"
      case "Watch5,1", "Watch5,3": return "Apple Watch Series 5 40mm"
      case "Watch5,2", "Watch5,4": return "Apple Watch Series 5 44mm"
      case "Watch6,1", "Watch6,3": return "Apple Watch Series 6 40mm"
      case "Watch6,2", "Watch6,4": return "Apple Watch Series 6 44mm"
      case "Watch5,9", "Watch5,11": return "Apple Watch SE 40mm"
      case "Watch5,10", "Watch5,12": return "Apple Watch SE 44mm"
      case "Watch6,6", "Watch6,8": return "Apple Watch Series 7 41mm"
      case "Watch6,7", "Watch6,9": return "Apple Watch Series 7 45mm"
      case "Watch6,14", "Watch6,16": return "Apple Watch Series 8 41mm"
      case "Watch6,15", "Watch6,17": return "Apple Watch Series 8 45mm"
      case "Watch6,10", "Watch6,12": return "Apple Watch SE (2nd generation) 40mm"
      case "Watch6,11", "Watch6,13": return "Apple Watch SE (2nd generation) 44mm"
      case "Watch6,18": return "Apple Watch Ultra"
      case "Watch7,1", "Watch7,3": return "Apple Watch Series 9 41mm"
      case "Watch7,2", "Watch7,4": return "Apple Watch Series 9 45mm"
      case "Watch7,5": return "Apple Watch Ultra 2"
      case "Watch7,8", "Watch7,10": return "Apple Watch Series 10 42mm"
      case "Watch7,9", "Watch7,11": return "Apple Watch Series 10 46mm"
      case "Watch7,12": return "Apple Watch Ultra 3"
      case "Watch7,17", "Watch7,19": return "Apple Watch Series 11 42mm"
      case "Watch7,18", "Watch7,20": return "Apple Watch Series 11 46mm"
      case "i386", "x86_64", "arm64": return simulator(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "watchOS"))
      default: return unknown(identifier)
      }
    #elseif os(visionOS)
      // TODO: Replace with proper implementation for visionOS.
      switch identifier {
      case "i386", "x86_64", "arm64": return simulator(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "visionOS"))
      default: return unknown(identifier)
      }
    #else
      switch identifier {
      case "i386", "x86_64", "arm64": return simulator(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "macOS"))
      default: return unknown(identifier)
      }
    #endif
  }

  /// Returns a formatted string for unknown devices
  private static func unknown(_ identifier: String) -> String {
    return "Unknown (\(identifier))"
  }

  /// Returns a formatted string for simulator devices
  private static func simulator(_ deviceName: String) -> String {
    return "\(deviceName) Simulator"
  }

  /// Returns the human-readable device name (e.g., "iPhone 16 Pro Max")
  public static func getDeviceName() -> String {
    return mapToDevice(identifier: identifier)
  }

  /// Gets the battery level as a percentage (0.0 to 1.0). As of now, only iOS is supported via UIKIt.
  /// In the future, we can onboard to IOKit to get broader platform support.
  /// - Returns: Battery level where 0.0 = 0%, 1.0 = 100%, or nil if unavailable
  public static func getBatteryLevel() -> Double? {
    #if canImport(UIKit) && os(iOS)
      UIDevice.current.isBatteryMonitoringEnabled = true
      let level = UIDevice.current.batteryLevel
      return level >= 0 ? roundValue(Double(level)) : nil
    #else
      return nil
    #endif
  }

  /// Gets CPU utilization as a ratio (0.0 to ~8.0+ on multi-core devices)
  ///
  /// Units: Ratio where 1.0 = 100% of one CPU core
  /// - Single core at 50% = 0.5
  /// - Dual core at 100% each = 2.0
  /// - Quad core at 75% each = 3.0
  ///
  /// Calculates CPU usage by:
  /// 1. Getting all threads for the current task via `task_threads`
  /// 2. Querying each thread's basic info via `thread_info` with `THREAD_BASIC_INFO`
  /// 3. Summing `cpu_usage` for non-idle threads (where `TH_FLAGS_IDLE` is not set)
  /// 4. Normalizing by `TH_USAGE_SCALE` to get a 0.0-1.0 range per thread
  /// 5. Returning the total usage across all threads
  ///
  /// - Returns: CPU utilization ratio (rounded to 3 decimal places), or nil if calculation fails
  public static func getCPUUsage() -> Double? {
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
      var totalUsage = 0.0
      var threadsList: thread_act_array_t?
      var threadsCount = mach_msg_type_number_t(0)

      guard task_threads(mach_task_self_, &threadsList, &threadsCount) == KERN_SUCCESS else {
        return nil
      }

      defer {
        if let threadsList {
          vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }
      }

      for index in 0 ..< threadsCount {
        var threadInfo = thread_basic_info()
        var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

        let result = withUnsafeMutablePointer(to: &threadInfo) {
          $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            thread_info(threadsList![Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
          }
        }

        if result == KERN_SUCCESS {
          if threadInfo.flags & TH_FLAGS_IDLE == 0 {
            totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
          }
        }
      }
      return roundValue(totalUsage)
    #else
      return nil
    #endif
  }

  /// Gets memory usage in megabytes (RSS - Resident Set Size)
  ///
  /// Units: Megabytes of physical memory currently used by the process
  /// - Example: 100.0 = 100 MB
  /// - Example: 1024.0 = 1 GB
  ///
  /// Calculates memory usage by:
  /// 1. Calling `task_info` with `MACH_TASK_BASIC_INFO` flavor
  /// 2. Extracting `resident_size` from `mach_task_basic_info` struct
  /// 3. Converting bytes to megabytes and rounding to 3 decimal places
  ///
  /// - Returns: Memory usage in megabytes as Double, or nil if calculation fails
  public static func getMemoryUsage() -> Double? {
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
      var info = mach_task_basic_info()
      var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

      let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
          task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
      }

      guard result == KERN_SUCCESS else { return nil }

      let memoryMB = Double(info.resident_size) / (1024 * 1024)
      return roundValue(memoryMB)
    #else
      return nil
    #endif
  }
}
