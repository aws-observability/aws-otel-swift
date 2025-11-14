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

class MockDeviceKit: DeviceKitPolyfillProtocol {
  static var batteryCallCount = 0
  static var cpuCallCount = 0
  static var memoryCallCount = 0

  static func getBatteryLevel() -> Double? {
    batteryCallCount += 1
    return 0.75
  }

  static func getCPUUsage() -> Double? {
    cpuCallCount += 1
    return 0.5
  }

  static func getMemoryUsage() -> Double? {
    memoryCallCount += 1
    return 100.0
  }

  static func getDeviceName() -> String {
    return "Mock Device"
  }
}

class AwsDeviceKitManagerTests: XCTestCase {
  func testSharedInstance() {
    let instance1 = AwsDeviceKitManager.shared
    let instance2 = AwsDeviceKitManager.shared
    XCTAssertTrue(instance1 === instance2)
  }

  func testGetBatteryLevel() {
    let batteryLevel = AwsDeviceKitManager.shared.getBatteryLevel()
    #if os(iOS) || os(tvOS)
      if let level = batteryLevel {
        XCTAssertGreaterThanOrEqual(level, 0.0)
        XCTAssertLessThanOrEqual(level, 1.0)
      }
    #else
      XCTAssertNil(batteryLevel)
    #endif
  }

  func testGetCPUUtil() {
    let cpuUtil = AwsDeviceKitManager.shared.getCPUUtil()
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
      if let cpu = cpuUtil {
        XCTAssertGreaterThanOrEqual(cpu, 0.0)
      }
    #else
      XCTAssertNil(cpuUtil)
    #endif
  }

  func testGetMemoryUsage() {
    let memoryUsage = AwsDeviceKitManager.shared.getMemoryUsage()
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
      if let memory = memoryUsage {
        XCTAssertGreaterThan(memory, 0)
      }
    #else
      XCTAssertNil(memoryUsage)
    #endif
  }

  func testRateLimiting() {
    MockDeviceKit.batteryCallCount = 0
    MockDeviceKit.cpuCallCount = 0
    MockDeviceKit.memoryCallCount = 0

    let manager = AwsDeviceKitManager(deviceKit: MockDeviceKit.self)

    _ = manager.getBatteryLevel()
    _ = manager.getBatteryLevel()
    XCTAssertEqual(MockDeviceKit.batteryCallCount, 1)

    _ = manager.getCPUUtil()
    _ = manager.getCPUUtil()
    XCTAssertEqual(MockDeviceKit.cpuCallCount, 1)

    _ = manager.getMemoryUsage()
    _ = manager.getMemoryUsage()
    XCTAssertEqual(MockDeviceKit.memoryCallCount, 1)
  }

  func testThreadSafety() {
    MockDeviceKit.batteryCallCount = 0
    MockDeviceKit.cpuCallCount = 0
    MockDeviceKit.memoryCallCount = 0

    let manager = AwsDeviceKitManager(deviceKit: MockDeviceKit.self)
    let expectation = expectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 10

    for _ in 0 ..< 10 {
      DispatchQueue.global().async {
        let battery = manager.getBatteryLevel()
        let cpu = manager.getCPUUtil()
        let memory = manager.getMemoryUsage()

        XCTAssertEqual(battery, 0.75)
        XCTAssertEqual(cpu, 0.5)
        XCTAssertEqual(memory, 100.0)

        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: 2.0)
    XCTAssertEqual(MockDeviceKit.batteryCallCount, 1)
    XCTAssertEqual(MockDeviceKit.cpuCallCount, 1)
    XCTAssertEqual(MockDeviceKit.memoryCallCount, 1)
  }
}
