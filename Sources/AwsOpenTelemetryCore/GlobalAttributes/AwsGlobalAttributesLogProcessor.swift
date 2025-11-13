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
import OpenTelemetryApi

class AwsGlobalAttributesLogProcessor: LogRecordProcessor {
  private var globalAttributesManager: AwsGlobalAttributesManager
  private var nextProcessor: LogRecordProcessor

  init(nextProcessor: LogRecordProcessor, globalAttributesManager: AwsGlobalAttributesManager? = nil) {
    self.nextProcessor = nextProcessor
    self.globalAttributesManager = globalAttributesManager ?? AwsGlobalAttributesProvider.getInstance()
  }

  func onEmit(logRecord: ReadableLogRecord) {
    var enhancedRecord = logRecord
    let globalAttributes = globalAttributesManager.getAttributes()

    for (key, value) in globalAttributes {
      enhancedRecord.setAttribute(key: key, value: value)
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
