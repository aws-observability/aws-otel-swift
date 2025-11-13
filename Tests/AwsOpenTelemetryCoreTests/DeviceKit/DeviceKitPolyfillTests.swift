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

class DeviceKitPolyfillTests: XCTestCase {
  #if os(iOS)
    func testIPhoneModels() {
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone3,1"), "iPhone 4")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone4,1"), "iPhone 4s")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone5,1"), "iPhone 5")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone5,3"), "iPhone 5c")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone6,1"), "iPhone 5s")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone7,2"), "iPhone 6")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone7,1"), "iPhone 6 Plus")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone8,1"), "iPhone 6s")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone8,2"), "iPhone 6s Plus")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone9,1"), "iPhone 7")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone9,2"), "iPhone 7 Plus")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone8,4"), "iPhone SE")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone10,1"), "iPhone 8")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone10,2"), "iPhone 8 Plus")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone10,3"), "iPhone X")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone11,2"), "iPhone XS")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone11,4"), "iPhone XS Max")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone11,8"), "iPhone XR")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone12,1"), "iPhone 11")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone12,3"), "iPhone 11 Pro")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone12,5"), "iPhone 11 Pro Max")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone12,8"), "iPhone SE (2nd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone13,2"), "iPhone 12")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone13,1"), "iPhone 12 mini")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone13,3"), "iPhone 12 Pro")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone13,4"), "iPhone 12 Pro Max")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone14,5"), "iPhone 13")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone14,4"), "iPhone 13 mini")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone14,2"), "iPhone 13 Pro")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone14,3"), "iPhone 13 Pro Max")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone14,6"), "iPhone SE (3rd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone14,7"), "iPhone 14")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone14,8"), "iPhone 14 Plus")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone15,2"), "iPhone 14 Pro")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone15,3"), "iPhone 14 Pro Max")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone15,4"), "iPhone 15")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone15,5"), "iPhone 15 Plus")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone16,1"), "iPhone 15 Pro")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone16,2"), "iPhone 15 Pro Max")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone17,3"), "iPhone 16")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone17,4"), "iPhone 16 Plus")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone17,1"), "iPhone 16 Pro")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone17,2"), "iPhone 16 Pro Max")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone17,5"), "iPhone 16e")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone18,3"), "iPhone 17")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone18,1"), "iPhone 17 Pro")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone18,2"), "iPhone 17 Pro Max")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPhone18,4"), "iPhone Air")
    }

    func testIPadModels() {
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad2,1"), "iPad 2")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad3,1"), "iPad (3rd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad3,4"), "iPad (4th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad4,1"), "iPad Air")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad5,3"), "iPad Air 2")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad6,11"), "iPad (5th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad7,5"), "iPad (6th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad11,3"), "iPad Air (3rd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad7,11"), "iPad (7th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad11,6"), "iPad (8th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad12,1"), "iPad (9th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad13,18"), "iPad (10th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad15,7"), "iPad (A16)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad13,1"), "iPad Air (4th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad13,16"), "iPad Air (5th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad14,8"), "iPad Air (11-inch) (M2)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad14,10"), "iPad Air (13-inch) (M2)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad15,3"), "iPad Air (11-inch) (M3)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad15,5"), "iPad Air (13-inch) (M3)")
    }

    func testIPadProModels() {
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad6,3"), "iPad Pro (9.7-inch)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad6,7"), "iPad Pro (12.9-inch)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad7,1"), "iPad Pro (12.9-inch) (2nd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad7,3"), "iPad Pro (10.5-inch)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad8,1"), "iPad Pro (11-inch)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad8,5"), "iPad Pro (12.9-inch) (3rd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad8,9"), "iPad Pro (11-inch) (2nd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad8,11"), "iPad Pro (12.9-inch) (4th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad13,4"), "iPad Pro (11-inch) (3rd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad13,8"), "iPad Pro (12.9-inch) (5th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad14,3"), "iPad Pro (11-inch) (4th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad14,5"), "iPad Pro (12.9-inch) (6th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad16,3"), "iPad Pro (11-inch) (M4)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad16,5"), "iPad Pro (13-inch) (M4)")
    }

    func testIPadMiniModels() {
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad2,5"), "iPad Mini")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad4,4"), "iPad Mini 2")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad4,7"), "iPad Mini 3")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad5,1"), "iPad Mini 4")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad11,1"), "iPad Mini (5th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad14,1"), "iPad Mini (6th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPad16,1"), "iPad Mini (A17 Pro)")
    }

    func testIPodTouchModels() {
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPod5,1"), "iPod touch (5th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPod7,1"), "iPod touch (6th generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "iPod9,1"), "iPod touch (7th generation)")
    }

    func testGetBatteryLevel() {
      let batteryLevel = DeviceKitPolyfill.getBatteryLevel()
      if let level = batteryLevel {
        XCTAssertGreaterThanOrEqual(level, 0.0)
        XCTAssertLessThanOrEqual(level, 1.0)
      }
    }
  #endif

  #if os(tvOS)
    func testAppleTVModels() {
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "AppleTV5,3"), "Apple TV HD")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "AppleTV6,2"), "Apple TV 4K")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "AppleTV11,1"), "Apple TV 4K (2nd generation)")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "AppleTV14,1"), "Apple TV 4K (3rd generation)")
    }

    func testGetBatteryLevel() {
      let batteryLevel = DeviceKitPolyfill.getBatteryLevel()
      if let level = batteryLevel {
        XCTAssertGreaterThanOrEqual(level, 0.0)
        XCTAssertLessThanOrEqual(level, 1.0)
      }
    }
  #endif

  #if os(watchOS)

    func testAppleWatchModels() {
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch1,1"), "Apple Watch (1st generation) 38mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch1,2"), "Apple Watch (1st generation) 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch2,6"), "Apple Watch Series 1 38mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch2,7"), "Apple Watch Series 1 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch2,3"), "Apple Watch Series 2 38mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch2,4"), "Apple Watch Series 2 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch3,1"), "Apple Watch Series 3 38mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch3,3"), "Apple Watch Series 3 38mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch3,2"), "Apple Watch Series 3 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch3,4"), "Apple Watch Series 3 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch4,1"), "Apple Watch Series 4 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch4,3"), "Apple Watch Series 4 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch4,2"), "Apple Watch Series 4 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch4,4"), "Apple Watch Series 4 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch5,1"), "Apple Watch Series 5 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch5,3"), "Apple Watch Series 5 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch5,2"), "Apple Watch Series 5 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch5,4"), "Apple Watch Series 5 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,1"), "Apple Watch Series 6 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,3"), "Apple Watch Series 6 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,2"), "Apple Watch Series 6 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,4"), "Apple Watch Series 6 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch5,9"), "Apple Watch SE 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch5,11"), "Apple Watch SE 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch5,10"), "Apple Watch SE 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch5,12"), "Apple Watch SE 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,6"), "Apple Watch Series 7 41mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,8"), "Apple Watch Series 7 41mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,7"), "Apple Watch Series 7 45mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,9"), "Apple Watch Series 7 45mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,14"), "Apple Watch Series 8 41mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,16"), "Apple Watch Series 8 41mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,15"), "Apple Watch Series 8 45mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,17"), "Apple Watch Series 8 45mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,10"), "Apple Watch SE (2nd generation) 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,12"), "Apple Watch SE (2nd generation) 40mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,11"), "Apple Watch SE (2nd generation) 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,13"), "Apple Watch SE (2nd generation) 44mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch6,18"), "Apple Watch Ultra")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,1"), "Apple Watch Series 9 41mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,3"), "Apple Watch Series 9 41mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,2"), "Apple Watch Series 9 45mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,4"), "Apple Watch Series 9 45mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,5"), "Apple Watch Ultra 2")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,8"), "Apple Watch Series 10 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,10"), "Apple Watch Series 10 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,9"), "Apple Watch Series 10 46mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,11"), "Apple Watch Series 10 46mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,12"), "Apple Watch Ultra 3")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,17"), "Apple Watch Series 11 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,19"), "Apple Watch Series 11 42mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,18"), "Apple Watch Series 11 46mm")
      XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "Watch7,20"), "Apple Watch Series 11 46mm")
    }

    func testGetBatteryLevel() {
      let batteryLevel = DeviceKitPolyfill.getBatteryLevel()
      XCTAssertNil(batteryLevel)
    }
  #endif

  func testSimulatorIdentifiers() {
    // Simulator identifiers should return simulator format with fallback device name
    let i386Result = DeviceKitPolyfill.mapToDevice(identifier: "i386")
    XCTAssertTrue(i386Result.contains("Simulator"), "Expected result to contain 'Simulator', but got: \(i386Result)")

    let x86Result = DeviceKitPolyfill.mapToDevice(identifier: "x86_64")
    XCTAssertTrue(x86Result.contains("Simulator"), "Expected result to contain 'Simulator', but got: \(x86Result)")

    let armResult = DeviceKitPolyfill.mapToDevice(identifier: "arm64")
    XCTAssertTrue(armResult.contains("Simulator"), "Expected result to contain 'Simulator', but got: \(armResult)")
  }

  func testUnknownIdentifier() {
    XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "UnknownDevice1,1"), "Unknown (UnknownDevice1,1)")
    XCTAssertEqual(DeviceKitPolyfill.mapToDevice(identifier: "FutureDevice99,99"), "Unknown (FutureDevice99,99)")
  }

  func testGetDeviceName() {
    let deviceName = DeviceKitPolyfill.getDeviceName()
    XCTAssertFalse(deviceName.isEmpty)
    XCTAssertTrue(deviceName.count > 0)
  }

  func testGetBatteryLevel() {
    let batteryLevel = DeviceKitPolyfill.getBatteryLevel()

    #if canImport(UIKit) && !os(watchOS)
      // On iOS/iPadOS/tvOS, battery level should be available or nil
      if let level = batteryLevel {
        XCTAssertGreaterThanOrEqual(level, 0.0)
        XCTAssertLessThanOrEqual(level, 1.0)
      }
    #else
      // On macOS/watchOS, battery level should be nil
      XCTAssertNil(batteryLevel)
    #endif
  }

  func testGetCPUUsage() {
    let cpuUsage = DeviceKitPolyfill.getCPUUsage()
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
      if let cpu = cpuUsage {
        XCTAssertGreaterThanOrEqual(cpu, 0.0)
      }
    #else
      XCTAssertNil(cpuUsage)
    #endif
  }

  func testGetMemoryUsage() {
    let memoryUsage = DeviceKitPolyfill.getMemoryUsage()
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
      if let memory = memoryUsage {
        XCTAssertGreaterThan(memory, 0)
      }
    #else
      XCTAssertNil(memoryUsage)
    #endif
  }
}
