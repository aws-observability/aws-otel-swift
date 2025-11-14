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
import OpenTelemetrySdk

/**
 * Log processor that adds device metrics as attributes:
 * - Battery level: 0.0-1.0 (percentage as ratio)
 * - CPU utilization: 0.0+ (ratio where 1.0 = 100% of one core)
 * - Memory usage: MB (physical memory RSS in megabytes)
 */
class AwsDeviceKitLogProcessor: LogRecordProcessor {
  private var nextProcessor: LogRecordProcessor

  init(nextProcessor: LogRecordProcessor) {
    self.nextProcessor = nextProcessor
  }

  func onEmit(logRecord: ReadableLogRecord) {
    var enhancedRecord = logRecord

    if let batteryLevel = AwsDeviceKitManager.shared.getBatteryLevel() {
      enhancedRecord.setAttribute(key: AwsDeviceKitSemConv.batteryCharge, value: .double(batteryLevel))
    }
    if let cpuUtil = AwsDeviceKitManager.shared.getCPUUtil() {
      enhancedRecord.setAttribute(key: AwsDeviceKitSemConv.cpuUtilization, value: .double(cpuUtil))
    }
    if let memoryUsage = AwsDeviceKitManager.shared.getMemoryUsage() {
      enhancedRecord.setAttribute(key: AwsDeviceKitSemConv.memoryUsage, value: .double(memoryUsage))
    }

    nextProcessor.onEmit(logRecord: enhancedRecord)
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
