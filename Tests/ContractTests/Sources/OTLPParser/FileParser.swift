import Foundation

enum OtlpFileParser {
  static func readTracesFile(file: URL) -> [TraceRoot] {
    var traceRoots: [TraceRoot] = []

    if let content = try? String(contentsOf: file, encoding: .utf8) {
      content.components(separatedBy: .newlines).forEach { line in
        if !line.isEmpty {
          if let data = line.data(using: .utf8),
             let root = try? JSONDecoder().decode(TraceRoot.self, from: data) {
            traceRoots.append(root)
          }
        }
      }
    }

    return traceRoots
  }

  static func readLogsFile(file: URL) -> [LogRoot] {
    var logRoots: [LogRoot] = []

    if let content = try? String(contentsOf: file, encoding: .utf8) {
      content.components(separatedBy: .newlines).forEach { line in
        if !line.isEmpty {
          if let data = line.data(using: .utf8),
             let root = try? JSONDecoder().decode(LogRoot.self, from: data) {
            logRoots.append(root)
          }
        }
      }
    }

    return logRoots
  }
}
