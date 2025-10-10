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

class GlobalAttributesLogRecordProcessor: LogRecordProcessor {
  private var globalAttributesManager: GlobalAttributesManager
  private var nextProcessor: LogRecordProcessor

  init(nextProcessor: LogRecordProcessor, globalAttributesManager: GlobalAttributesManager? = nil) {
    self.nextProcessor = nextProcessor
    self.globalAttributesManager = globalAttributesManager ?? GlobalAttributesProvider.getInstance()
  }

  func onEmit(logRecord: ReadableLogRecord) {
    var newAttributes = logRecord.attributes
    let globalAttributes = globalAttributesManager.getAttributes()

    for (key, value) in globalAttributes {
      newAttributes[key] = value
    }

    let enhancedRecord = ReadableLogRecord(
      resource: logRecord.resource,
      instrumentationScopeInfo: logRecord.instrumentationScopeInfo,
      timestamp: logRecord.timestamp,
      observedTimestamp: logRecord.observedTimestamp,
      spanContext: logRecord.spanContext,
      severity: logRecord.severity,
      body: logRecord.body,
      attributes: newAttributes
    )

    nextProcessor.onEmit(logRecord: enhancedRecord)
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
