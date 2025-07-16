import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// A simple in-memory log exporter for testing purposes
public class InMemoryLogExporter: LogRecordExporter {
  private var exportedLogs: [ReadableLogRecord] = []

  public init() {}

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    exportedLogs.append(contentsOf: logRecords)
    return .success
  }

  public func flush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  public func shutdown(explicitTimeout: TimeInterval?) {}

  public func getExportedLogs() -> [ReadableLogRecord] {
    return exportedLogs
  }

  public func reset() {
    exportedLogs.removeAll()
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  public static func register() -> InMemoryLogExporter {
    // Create an in-memory log exporter
    let logExporter = InMemoryLogExporter()

    // Create and register a LoggerProvider with the in-memory exporter
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
      .build()

    // Register the logger provider with OpenTelemetry
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

    return logExporter
  }

  public func clear() {
    exportedLogs.removeAll()
  }
}
