import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

/// AWS OTel log record processor that adds session attributes to all log records
class AwsSessionLogRecordProcessor: LogRecordProcessor {
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
    AwsOpenTelemetryLogger.debug("Initializing AwsSessionLogRecordProcessor")
  }

  /// Called when a log record is emitted - adds session attributes and forwards to next processor
  /// - Parameter logRecord: The log record being processed
  func onEmit(logRecord: ReadableLogRecord) {
    var mutatedRecord = logRecord

    // For session.start and session.end events, preserve existing session attributes
    if let body = logRecord.body,
       case let .string(bodyString) = body,
       bodyString == AwsSessionConstants.sessionStartEvent || bodyString == AwsSessionConstants.sessionEndEvent {
      // Do nothing
      // - Session start and end events already have their intended session ids.
      // - Overwriting them here will also cause session end to have the wrong current and prev session ids.
    } else {
      // For other log records, add current session attributes
      let session = sessionManager.getSession()
      mutatedRecord.setAttribute(key: AwsSessionConstants.id, value: AttributeValue.string(session.id))
      if let previousId = session.previousId {
        mutatedRecord.setAttribute(key: AwsSessionConstants.previousId, value: AttributeValue.string(previousId))
      }
    }

    nextProcessor.onEmit(logRecord: mutatedRecord)
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
