import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

/// AWS OTel log record processor that adds session attributes to all log records
class AwsScreenLogRecordProcessor: LogRecordProcessor {
  /// Reference to the session manager for retrieving current session
  private var screenManager: AwsScreenManager
  /// The next processor in the chain
  private var nextProcessor: LogRecordProcessor

  /// Initializes the log record processor with a session manager from the provider
  /// - Parameters:
  ///   - nextProcessor: The next processor to call after adding session attributes
  ///   - screenManager: Optional session manager, defaults to provider instance
  init(nextProcessor: LogRecordProcessor, screenManager: AwsScreenManager? = nil) {
    self.nextProcessor = nextProcessor
    self.screenManager = screenManager ?? AwsScreenManagerProvider.getInstance()
  }

  /// Called when a log record is emitted - adds session attributes and forwards to next processor
  /// - Parameter logRecord: The log record being processed
  func onEmit(logRecord: ReadableLogRecord) {
    var enhancedRecord = logRecord

    // Only add session attributes if they don't already exist
    if let screenName = screenManager.currentScreen, logRecord.attributes[AwsViewSemConv.screenName] == nil {
      enhancedRecord.setAttribute(key: AwsViewSemConv.screenName, value: screenName)
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
