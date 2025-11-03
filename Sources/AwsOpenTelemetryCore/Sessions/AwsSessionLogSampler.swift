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

/// Log processor that drops log records for unsampled sessions
public class AwsSessionLogSampler: LogRecordProcessor {
  private let sessionManager: AwsSessionManager
  private let nextProcessor: LogRecordProcessor

  public init(nextProcessor: LogRecordProcessor, sessionManager: AwsSessionManager? = nil) {
    self.nextProcessor = nextProcessor
    self.sessionManager = sessionManager ?? AwsSessionManagerProvider.getInstance()
  }

  public func onEmit(logRecord: ReadableLogRecord) {
    guard sessionManager.isSessionSampled else {
      return
    }
    nextProcessor.onEmit(logRecord: logRecord)
  }

  public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return nextProcessor.shutdown(explicitTimeout: explicitTimeout)
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return nextProcessor.forceFlush(explicitTimeout: explicitTimeout)
  }
}
