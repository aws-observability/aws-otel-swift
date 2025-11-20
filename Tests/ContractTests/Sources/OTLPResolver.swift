import Foundation

struct ParsedOtlpData {
  let logs: [LogRoot]
  let traces: [TraceRoot]
}

class OtlpResolver {
  private static let LOGS_LOCATION = "Examples/AwsOtelUI/out/logs.jsonl"
  private static let TRACES_LOCATION = "Examples/AwsOtelUI/out/traces.jsonl"

  static var shared: OtlpResolver! {
    return OtlpResolver()
  }

  var parsedData: ParsedOtlpData! {
    return Self.parseData()
  }

  private init() {}

  private static func parseData() -> ParsedOtlpData {
    // Find project root by looking for Package.swift
    let currentDir = FileManager.default.currentDirectoryPath
    var projectRoot = currentDir
    while !FileManager.default.fileExists(atPath: "\(projectRoot)/Package.swift") {
      let parent = (projectRoot as NSString).deletingLastPathComponent
      if parent == projectRoot { break } // Reached filesystem root
      projectRoot = parent
    }

    let logsPath = "\(projectRoot)/\(LOGS_LOCATION)"
    let tracesPath = "\(projectRoot)/\(TRACES_LOCATION)"
    let logsFileURL = URL(fileURLWithPath: logsPath)
    let tracesFileURL = URL(fileURLWithPath: tracesPath)

    if !FileManager.default.fileExists(atPath: logsPath) ||
      !FileManager.default.fileExists(atPath: tracesPath) {
      print("[ERROR] Could not find logs and traces files at expected locations: \(logsPath), \(tracesPath)")
    }

    return ParsedOtlpData(logs: OtlpFileParser.readLogsFile(file: logsFileURL), traces: OtlpFileParser.readTracesFile(file: tracesFileURL))
  }
}
