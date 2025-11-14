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

/// Log record processor that adds battery level to log records
public class DeviceKitLogRecordProcessor: LogRecordProcessor {
  private var nextProcessor: LogRecordProcessor

  public init(nextProcessor: LogRecordProcessor) {
    self.nextProcessor = nextProcessor
  }

  public func onEmit(logRecord: ReadableLogRecord) {
    var mutatedRecord = logRecord
    if let batteryLevel = DeviceKitPolyfill.getBatteryLevel() {
      mutatedRecord.setAttribute(key: "hw.battery.charge", value: AttributeValue.double(Double(batteryLevel)))
    }
    nextProcessor.onEmit(logRecord: mutatedRecord)
  }

  /// Shuts down the processor - no cleanup needed
  /// - Parameter explicitTimeout: Timeout for shutdown (unused)
  /// - Returns: Success result
  public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  /// Forces a flush of any pending data - no action needed
  /// - Parameter explicitTimeout: Timeout for flush (unused)
  /// - Returns: Success result
  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
