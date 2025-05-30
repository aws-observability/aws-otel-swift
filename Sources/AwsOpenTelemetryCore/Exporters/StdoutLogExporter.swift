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

// TODO: Delete once upstream's is made public

import Foundation
import OpenTelemetrySdk

class StdoutLogExporter: LogRecordExporter {
  let isDebug: Bool

  init(isDebug: Bool = false) {
    self.isDebug = isDebug
  }

  func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
    if isDebug {
      for logRecord in logRecords {
        print(String(repeating: "-", count: 40))
        print("Severity: \(String(describing: logRecord.severity))")
        print("Body: \(String(describing: logRecord.body))")
        print("InstrumentationScopeInfo: \(logRecord.instrumentationScopeInfo)")
        print("Timestamp: \(logRecord.timestamp)")
        print("ObservedTimestamp: \(String(describing: logRecord.observedTimestamp))")
        print("SpanContext: \(String(describing: logRecord.spanContext))")
        print("Resource: \(logRecord.resource.attributes)")
        print("Attributes: \(logRecord.attributes)")
        print(String(repeating: "-", count: 40) + "\n")
      }
    } else {
      do {
        let jsonData = try JSONEncoder().encode(logRecords)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
          print(jsonString)
        }
      } catch {
        print("Failed to serialize LogRecord as JSON: \(error)")
        return .failure
      }
    }
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
    return .success
  }

  func shutdown(explicitTimeout: TimeInterval?) {}
}
