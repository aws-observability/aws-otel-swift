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

/// AWS OTel log record processor that adds session attributes to all log records
class AwsSessionLogProcessor: LogRecordProcessor {
  /// Reference to the session manager for retrieving current session
  private var sessionManager: AwsSessionManager
  /// The next processor in the chain
  private var nextProcessor: LogRecordProcessor

  /// Initializes the log record processor with a session manager from the provider
  /// - Parameters:
  ///   - nextProcessor: The next processor to call after adding session attributes
  ///   - sessionManager: Optional session manager, defaults to provider instance
  init(nextProcessor: LogRecordProcessor, sessionManager: AwsSessionManager? = nil) {
    self.nextProcessor = nextProcessor
    self.sessionManager = sessionManager ?? AwsSessionManagerProvider.getInstance()
  }

  /// Called when a log record is emitted - adds session attributes and forwards to next processor
  /// - Parameter logRecord: The log record being processed
  func onEmit(logRecord: ReadableLogRecord) {
    var enhancedRecord = logRecord

    // Only add session attributes if they don't already exist
    if logRecord.attributes[AwsSessionSemConv.id] == nil || logRecord.attributes[AwsSessionSemConv.previousId] == nil {
      let session = sessionManager.getSession()

      // Add session.id if not already present
      if logRecord.attributes[AwsSessionSemConv.id] == nil {
        enhancedRecord.setAttribute(key: AwsSessionSemConv.id, value: session.id)
      }

      // Add session.previous_id if not already present and session has a previous ID
      if logRecord.attributes[AwsSessionSemConv.previousId] == nil, let previousId = session.previousId {
        enhancedRecord.setAttribute(key: AwsSessionSemConv.previousId, value: previousId)
      }
    }

    nextProcessor.onEmit(logRecord: enhancedRecord)
  }

  /// Shuts down the processor - no cleanup needed
  /// - Parameter explicitTimeout: Timeout for shutdown (unused)
  /// - Returns: Success result
  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  /// Forces a flush of any pending data - no action needed
  /// - Parameter explicitTimeout: Timeout for flush (unused)
  /// - Returns: Success result
  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
