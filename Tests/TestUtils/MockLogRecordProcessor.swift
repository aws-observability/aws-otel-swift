import Foundation
import OpenTelemetrySdk

public class MockLogRecordProcessor: LogRecordProcessor {
  private let lock = NSLock()
  private var _processedLogRecords: [ReadableLogRecord] = []

  public var processedLogRecords: [ReadableLogRecord] {
    return lock.withLock { _processedLogRecords }
  }

  public var receivedLogRecords: [ReadableLogRecord] {
    return processedLogRecords
  }

  public init() {}

  public func onEmit(logRecord: ReadableLogRecord) {
    lock.withLock {
      _processedLogRecords.append(logRecord)
    }
  }

  public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
