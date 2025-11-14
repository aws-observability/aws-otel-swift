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
import OpenTelemetryApi
import OpenTelemetrySdk

/**
 * Span processor that adds device metrics as attributes:
 * - Battery level: 0.0-1.0 (percentage as ratio)
 * - CPU utilization: 0.0+ (ratio where 1.0 = 100% of one core)
 * - Memory usage: MB (physical memory RSS in megabytes)
 */
public class AwsDeviceKitSpanProcessor: SpanProcessor {
  public var isStartRequired = true
  public var isEndRequired: Bool = false

  public init() {}

  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    if let batteryLevel = AwsDeviceKitManager.shared.getBatteryLevel() {
      span.setAttribute(key: AwsDeviceKitSemConv.batteryCharge, value: batteryLevel)
    }
    if let cpuUtil = AwsDeviceKitManager.shared.getCPUUtil() {
      span.setAttribute(key: AwsDeviceKitSemConv.cpuUtilization, value: cpuUtil)
    }
    if let memoryUsage = AwsDeviceKitManager.shared.getMemoryUsage() {
      span.setAttribute(key: AwsDeviceKitSemConv.memoryUsage, value: memoryUsage)
    }
  }

  public func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
    // No action needed
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    // No cleanup needed
  }

  public func forceFlush(timeout: TimeInterval?) {
    // No action needed
  }
}
