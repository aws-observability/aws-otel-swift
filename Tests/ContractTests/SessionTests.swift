import XCTest
@testable import AwsOpenTelemetryCore

class SessionTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // Verifies that session start events are logged correctly
  func testSessionStartLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionStartLogs = sessionLogs.flatMap(\.logRecords).filter { $0.eventName == "session.start" }

    XCTAssertEqual(sessionStartLogs.count, 2, "Should have exactly 2 session start logs")
  }

  // Verifies session IDs link correctly between session events
  func testSessionLinking() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionStartLogs = sessionLogs.flatMap(\.logRecords).filter { $0.eventName == "session.start" }.sorted { UInt64($0.observedTimeUnixNano ?? $0.timeUnixNano) ?? 0 < UInt64($1.observedTimeUnixNano ?? $1.timeUnixNano) ?? 0 }
    let sessionEndLogs = sessionLogs.flatMap(\.logRecords).filter { $0.eventName == "session.end" }.sorted { UInt64($0.observedTimeUnixNano ?? $0.timeUnixNano) ?? 0 < UInt64($1.observedTimeUnixNano ?? $1.timeUnixNano) ?? 0 }

    XCTAssertEqual(sessionStartLogs.count, 2, "Should have 2 session start logs")
    XCTAssertGreaterThanOrEqual(sessionEndLogs.count, 1, "Should have at least 1 session end log")

    // Get the last session end event
    let lastSessionEnd = sessionEndLogs.last!
    guard let lastEndSessionId = lastSessionEnd.attributes.first(where: { $0.key == "session.id" })?.value.stringValue else {
      XCTFail("Last session end should have session.id and session.previous_id")
      return
    }

    // First session start should have same session.id as last session end
    let firstSessionStart = sessionStartLogs[0]
    guard let firstStartSessionId = firstSessionStart.attributes.first(where: { $0.key == "session.id" })?.value.stringValue else {
      XCTFail("First session start should have session.id and session.previous_id")
      return
    }
    XCTAssertEqual(firstStartSessionId, lastEndSessionId, "First session start session.id should match last session end ID")

    // Second session start's previous_id should match first session start's session.id
    let secondSessionStart = sessionStartLogs[1]
    guard let secondStartPreviousId = secondSessionStart.attributes.first(where: { $0.key == "session.previous_id" })?.value.stringValue else {
      XCTFail("Second session start should have session.previous_id")
      return
    }
    XCTAssertEqual(firstStartSessionId, secondStartPreviousId, "Second session start previous_id should match first session start session.id")
  }

  // Verifies all events within a session have the same session ID
  func testSessionIdConsistency() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionStartLogs = sessionLogs.flatMap(\.logRecords).filter { $0.eventName == "session.start" }.sorted { UInt64($0.timeUnixNano) ?? 0 < UInt64($1.timeUnixNano) ?? 0 }

    XCTAssertEqual(sessionStartLogs.count, 2, "Should have exactly 2 session start logs")

    guard sessionStartLogs.count == 2,
          let t1 = UInt64(sessionStartLogs[0].timeUnixNano),
          let t2 = UInt64(sessionStartLogs[1].timeUnixNano),
          let sessionId1 = sessionStartLogs[0].attributes.first(where: { $0.key == "session.id" })?.value.stringValue,
          let sessionId2 = sessionStartLogs[1].attributes.first(where: { $0.key == "session.id" })?.value.stringValue else {
      XCTFail("Could not extract session times and IDs")
      return
    }

    // Get sessionId_A from session.end event before t1
    let sessionEndLogs = sessionLogs.flatMap(\.logRecords).filter { $0.eventName == "session.end" }
    let sessionEndBeforeT1 = sessionEndLogs.first { UInt64($0.timeUnixNano) ?? 0 < t1 }
    let sessionIdA = sessionEndBeforeT1?.attributes.first(where: { $0.key == "session.id" })?.value.stringValue

    func checkEvent(time: UInt64, sessionId: String?, eventName: String) {
      let tolerance: UInt64 = 50_000_000 // 50ms in nanoseconds
      let expectedSessionId: String? = if time < t1 - tolerance {
        sessionIdA
      } else if time < t2 - tolerance {
        sessionId1
      } else {
        sessionId2
      }

      if let actualSessionId = sessionId, let expected = expectedSessionId, actualSessionId != expected {
        print("Mismatch - Event: \(eventName), Time: \(time), Actual: \(actualSessionId), Expected: \(expected)")
        XCTFail("Session ID mismatch for \(eventName)")
      }
    }

    // Check all logs
    for logRoot in data?.logs ?? [] {
      for resourceLog in logRoot.resourceLogs {
        for scopeLog in resourceLog.scopeLogs {
          for logRecord in scopeLog.logRecords {
            if let time = UInt64(logRecord.timeUnixNano) {
              let sessionId = logRecord.attributes.first(where: { $0.key == "session.id" })?.value.stringValue
              checkEvent(time: time, sessionId: sessionId, eventName: logRecord.eventName ?? "unknown")
            }
          }
        }
      }
    }

    // Check all spans
    for traceRoot in data?.traces ?? [] {
      for resourceSpan in traceRoot.resourceSpans {
        for scopeSpan in resourceSpan.scopeSpans {
          for span in scopeSpan.spans {
            if let time = UInt64(span.endTimeUnixNano) {
              let sessionId = span.attributes.first(where: { $0.key == "session.id" })?.value.stringValue
              checkEvent(time: time, sessionId: sessionId, eventName: span.name)
            }
          }
        }
      }
    }
  }

  // Verifies all events have the same anonymous user ID
  func testUserIdConsistency() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionStartLog = sessionLogs.flatMap(\.logRecords).first { $0.eventName == "session.start" }

    guard let expectedUserId = sessionStartLog?.attributes.first(where: { $0.key == "user.id" })?.value.stringValue else {
      XCTFail("Session start log should have user.id")
      return
    }

    // All logs with user.id should have the same value
    for logRoot in data?.logs ?? [] {
      for resourceLog in logRoot.resourceLogs {
        for scopeLog in resourceLog.scopeLogs {
          for logRecord in scopeLog.logRecords {
            if let logUserId = logRecord.attributes.first(where: { $0.key == "user.id" })?.value.stringValue {
              XCTAssertEqual(logUserId, expectedUserId, "All logs should have consistent user.id")
            }
          }
        }
      }
    }

    // All spans with user.id should have the same value
    for traceRoot in data?.traces ?? [] {
      for resourceSpan in traceRoot.resourceSpans {
        for scopeSpan in resourceSpan.scopeSpans {
          for span in scopeSpan.spans {
            if let spanUserId = span.attributes.first(where: { $0.key == "user.id" })?.value.stringValue {
              XCTAssertEqual(spanUserId, expectedUserId, "All spans should have consistent user.id")
            }
          }
        }
      }
    }
  }

  // Verifies session end events contain required attributes
  func testSessionEndLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionEndLog = sessionLogs.flatMap(\.logRecords).first { $0.eventName == "session.end" }

    XCTAssertNotNil(sessionEndLog, "Session end log should exist")
    XCTAssertNotNil(sessionEndLog?.attributes.first { $0.key == "session.id" }?.value.stringValue)
    XCTAssertNotNil(sessionEndLog?.attributes.first { $0.key == "user.id" }?.value.stringValue)
    XCTAssertNotNil(sessionEndLog?.attributes.first { $0.key == "session.previous_id" }?.value.stringValue)
  }
}
