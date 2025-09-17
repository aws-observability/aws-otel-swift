import Foundation
import OpenTelemetrySdk

class SpanExporterMock: SpanExporter {
  var exportCalledTimes: Int = 0
  var exportCalledData: [SpanData]?
  var shutdownCalledTimes: Int = 0
  var flushCalledTimes: Int = 0
  var returnValue: SpanExporterResultCode = .success
  var flushReturnValue: SpanExporterResultCode = .success

  func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    exportCalledTimes += 1
    exportCalledData = spans
    return returnValue
  }

  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    flushCalledTimes += 1
    return flushReturnValue
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    shutdownCalledTimes += 1
  }
}
