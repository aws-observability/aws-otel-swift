import Foundation

enum OtlpFileParser {
  static func readTracesFile(file: URL) -> [TraceRoot] {
    var traceRoots: [TraceRoot] = []

    if let content = try? String(contentsOf: file, encoding: .utf8) {
      let lines = content.components(separatedBy: .newlines)
      print("PARSER: Processing \(lines.count) lines from traces file")

      content.components(separatedBy: .newlines).forEach { line in
        if !line.isEmpty {
          if let data = line.data(using: .utf8) {
            do {
              let root = try JSONDecoder().decode(TraceRoot.self, from: data)
              traceRoots.append(root)
              print("PARSER: Successfully parsed trace with \(root.resourceSpans.count) resourceSpans")
            } catch {
              print("PARSER: JSON decode error: \(error)")
              print("PARSER: Failed line (first 200 chars): \(String(line.prefix(200)))")
            }
          }
        }
      }
    } else {
      print("PARSER: Could not read file at \(file.path)")
    }

    print("PARSER: Returning \(traceRoots.count) trace roots")
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
