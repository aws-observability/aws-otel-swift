import Foundation

struct ParsedOtlpData {
  let logs: [LogRoot]
  let traces: [TraceRoot]
}

class OtlpResolver {
  private static let LOGS_LOCATION = "/tmp/otel-swift-collector/logs.txt"
  private static let TRACES_LOCATION = "/tmp/otel-swift-collector/traces.txt"

  static let shared = OtlpResolver()

  let parsedData: ParsedOtlpData!

  private init() {
    let parsedData = Self.parseData()
    self.parsedData = parsedData
  }

  private static func parseData() -> ParsedOtlpData {
    let logsFileURL = URL(fileURLWithPath: LOGS_LOCATION)
    let tracesFileURL = URL(fileURLWithPath: TRACES_LOCATION)

    if !FileManager.default.fileExists(atPath: LOGS_LOCATION) ||
      !FileManager.default.fileExists(atPath: TRACES_LOCATION) {
      // Wait for files to exist (equivalent to Awaitility.await())
      var timeoutCount = 0
      while !FileManager.default.fileExists(atPath: LOGS_LOCATION) ||
        !FileManager.default.fileExists(atPath: TRACES_LOCATION) {
        Thread.sleep(forTimeInterval: 5.0) // 5 second interval
        timeoutCount += 1
        if timeoutCount >= 4 { // 20 seconds timeout (4 * 5 seconds)
          break
        }
      }
    } else {
      print("Found logs and traces files at expected locations: \(LOGS_LOCATION), \(TRACES_LOCATION)")
    }

    return ParsedOtlpData(logs: OtlpFileParser.readLogsFile(file: logsFileURL), traces: OtlpFileParser.readTracesFile(file: tracesFileURL))
  }
}
