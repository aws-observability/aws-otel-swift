import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

/// OpenTelemetry log record processor that adds UID to all log records
class AwsUIDLogRecordProcessor: LogRecordProcessor {
  /// The attribute key used to store UID in log records
  var userIdKey = "user.id"
  /// Reference to the UID manager for retrieving current UID
  private var uidManager: AwsUIDManager
  /// The next processor in the chain
  private var nextProcessor: LogRecordProcessor

  /// Initializes the log record processor with a UID manager from the provider
  /// - Parameters:
  ///   - nextProcessor: The next processor to call after adding UID
  ///   - uidManager: Optional UID manager, defaults to provider instance
  init(nextProcessor: LogRecordProcessor, uidManager: AwsUIDManager? = nil) {
    self.nextProcessor = nextProcessor
    self.uidManager = uidManager ?? AwsUIDManagerProvider.getInstance()
    AwsOpenTelemetryLogger.debug("Initializing AwsUIDLogRecordProcessor")
  }

  /// Called when a log record is emitted - adds UID and forwards to next processor
  /// - Parameter logRecord: The log record being processed
  func onEmit(logRecord: ReadableLogRecord) {
    let uid = uidManager.getUID()
    var newAttributes = logRecord.attributes
    newAttributes[userIdKey] = AttributeValue.string(uid)

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
