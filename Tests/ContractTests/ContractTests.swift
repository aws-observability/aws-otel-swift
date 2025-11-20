import XCTest
@testable import AwsOpenTelemetryCore

class AllEventsTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // MARK: - software.amazon.opentelemetry.appstart

  func testAppLaunchLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let appStartLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.appstart" }
    let launchLog = appStartLogs.flatMap(\.logRecords).first { $0.eventName == "UIApplicationDidFinishLaunchingNotification" }

    XCTAssertNotNil(launchLog, "App launch log should exist")
  }

  func testAppStartSpanExists() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let appStartSpans = spans.filter { $0.scope.name == "software.amazon.opentelemetry.appstart" }
    let appStartSpan = appStartSpans.flatMap(\.spans).first { $0.name == "AppStart" }

    XCTAssertNotNil(appStartSpan, "AppStart span should exist")
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "start.type" }?.value.stringValue, "cold")
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "screen.name" }?.value.stringValue, "ContentView")
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "active_prewarm" }?.value.boolValue, false)
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "launch_end_name" }?.value.stringValue, "UIApplicationDidBecomeActiveNotification")
    XCTAssertEqual(appStartSpan?.attributes.first { $0.key == "launch_start_name" }?.value.stringValue, "kp_proc.p_starttime")
  }

  func testWarmLaunchSpanExists() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let appStartSpans = spans.filter { $0.scope.name == "software.amazon.opentelemetry.appstart" }
    let warmLaunchSpan = appStartSpans.flatMap(\.spans).first { $0.attributes.contains { $0.key == "start.type" && $0.value.stringValue == "warm" } }

    XCTAssertNotNil(warmLaunchSpan, "Warm launch span should exist")
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "start.type" }?.value.stringValue, "warm")
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "screen.name" }?.value.stringValue, "ContentView")
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "active_prewarm" }?.value.boolValue, false)
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "launch_end_name" }?.value.stringValue, "UIApplicationDidBecomeActiveNotification")
    XCTAssertEqual(warmLaunchSpan?.attributes.first { $0.key == "launch_start_name" }?.value.stringValue, "UIApplicationWillEnterForegroundNotification")
  }

  // MARK: - software.amazon.opentelemetry.hang

  func testAppHangSpanExists() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let hangSpans = spans.filter { $0.scope.name == "software.amazon.opentelemetry.hang" }
    let hangSpan = hangSpans.flatMap(\.spans).first { $0.name == "device.hang" }

    XCTAssertNotNil(hangSpan, "App hang span should exist")
    XCTAssertEqual(hangSpan?.attributes.first { $0.key == "exception.type" }?.value.stringValue, "hang")
    XCTAssertEqual(hangSpan?.attributes.first { $0.key == "screen.name" }?.value.stringValue, "ContentView")

    // Verify exception message starts with expected text
    let exceptionMessage = hangSpan?.attributes.first { $0.key == "exception.message" }?.value.stringValue
    XCTAssertNotNil(exceptionMessage)
    XCTAssertTrue(exceptionMessage?.hasPrefix("Hang detected at libsystem_kernel.dylib") ?? false, "Exception message should start with 'Hang detected at libsystem_kernel.dylib'")

    // Verify stack trace contains thread information
    let stackTrace = hangSpan?.attributes.first { $0.key == "exception.stacktrace" }?.value.stringValue
    XCTAssertNotNil(stackTrace)
    XCTAssertTrue(stackTrace?.contains("Thread 0:") ?? false, "Stack trace should contain Thread 0")
    XCTAssertTrue(stackTrace?.contains("Crashed:") ?? false, "Stack trace should contain crashed thread")
    XCTAssertTrue(stackTrace?.contains("libsystem_kernel.dylib") ?? false, "Stack trace should contain libsystem_kernel.dylib")

    // Verify hang duration is approximately 5 seconds (allowing some tolerance)
    if let startTime = hangSpan?.startTimeUnixNano, let endTime = hangSpan?.endTimeUnixNano,
       let startNano = UInt64(startTime), let endNano = UInt64(endTime) {
      let durationSeconds = Double(endNano - startNano) / 1_000_000_000.0
      XCTAssertGreaterThan(durationSeconds, 4.0, "Hang duration should be at least 4 seconds")
      XCTAssertLessThan(durationSeconds, 6.0, "Hang duration should be less than 6 seconds")
    } else {
      XCTFail("Hang span should have valid start and end times")
    }
  }

  // MARK: - software.amazon.opentelemetry.session

  func testSessionStartLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionStartLogs = sessionLogs.flatMap(\.logRecords).filter { $0.eventName == "session.start" }

    XCTAssertEqual(sessionStartLogs.count, 2, "Should have exactly 2 session start logs")
  }

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

  func testSessionEndLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionEndLog = sessionLogs.flatMap(\.logRecords).first { $0.eventName == "session.end" }

    XCTAssertNotNil(sessionEndLog, "Session end log should exist")
    XCTAssertNotNil(sessionEndLog?.attributes.first { $0.key == "session.id" }?.value.stringValue)
    XCTAssertNotNil(sessionEndLog?.attributes.first { $0.key == "user.id" }?.value.stringValue)
    XCTAssertNotNil(sessionEndLog?.attributes.first { $0.key == "session.previous_id" }?.value.stringValue)
  }

  // MARK: - System Metrics

  func testSystemMetricsOnAllEvents() {
    // Note: Battery metrics are not supported in simulator environment for contract tests

    // Check all logs have memory and CPU metrics
    for logRoot in data?.logs ?? [] {
      for resourceLog in logRoot.resourceLogs {
        for scopeLog in resourceLog.scopeLogs {
          for logRecord in scopeLog.logRecords {
            let memoryUsage = logRecord.attributes.first { $0.key == "process.memory.usage" }?.value.doubleValue
            let cpuUtilization = logRecord.attributes.first { $0.key == "process.cpu.utilization" }?.value.doubleValue
            XCTAssertNotNil(memoryUsage, "Log \(logRecord.eventName ?? "unknown") should have memory usage")
            XCTAssertGreaterThan(memoryUsage ?? 0, 0, "Log \(logRecord.eventName ?? "unknown") memory usage should be > 0")
            XCTAssertNotNil(cpuUtilization, "Log \(logRecord.eventName ?? "unknown") should have CPU utilization")
            XCTAssertGreaterThanOrEqual(cpuUtilization ?? -1, 0, "Log \(logRecord.eventName ?? "unknown") CPU utilization should be >= 0")
          }
        }
      }
    }

    // Check all spans have memory and CPU metrics
    for traceRoot in data?.traces ?? [] {
      for resourceSpan in traceRoot.resourceSpans {
        for scopeSpan in resourceSpan.scopeSpans {
          for span in scopeSpan.spans {
            let memoryUsage = span.attributes.first { $0.key == "process.memory.usage" }?.value.doubleValue
            let cpuUtilization = span.attributes.first { $0.key == "process.cpu.utilization" }?.value.doubleValue
            XCTAssertNotNil(memoryUsage, "Span \(span.name) should have memory usage")
            XCTAssertGreaterThan(memoryUsage ?? 0, 0, "Span \(span.name) memory usage should be > 0")
            XCTAssertNotNil(cpuUtilization, "Span \(span.name) should have CPU utilization")
            XCTAssertGreaterThanOrEqual(cpuUtilization ?? -1, 0, "Span \(span.name) CPU utilization should be >= 0")
          }
        }
      }
    }
  }

  // MARK: - software.amazon.opentelemetry.swiftui

  func testScreenViewLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let swiftUILogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.swiftui" }
    let screenViewLog = swiftUILogs.flatMap(\.logRecords).first { $0.eventName == "app.screen.view_did_appear" }

    XCTAssertNotNil(screenViewLog, "Screen view log should exist")
    XCTAssertTrue(screenViewLog?.attributes.contains { $0.key == "screen.name" } ?? false)
    XCTAssertTrue(screenViewLog?.attributes.contains { $0.key == "app.screen.type" } ?? false)
    XCTAssertTrue(screenViewLog?.attributes.contains { $0.key == "app.screen.interaction" } ?? false)
    XCTAssertTrue(screenViewLog?.attributes.contains { $0.key == "app.screen.parent_screen.name" } ?? false)
    XCTAssertTrue(screenViewLog?.attributes.contains { $0.key == "session.id" } ?? false)
    XCTAssertTrue(screenViewLog?.attributes.contains { $0.key == "user.id" } ?? false)
  }

  func testScreenTimeToFirstAppearSpansExist() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let swiftUISpans = spans.filter { $0.scope.name == "software.amazon.opentelemetry.swiftui" }
    let screenSpans = swiftUISpans.flatMap(\.spans).filter { $0.name == "app.screen.time_to_first_appear" }

    XCTAssertFalse(screenSpans.isEmpty, "Screen time to first appear spans should exist")

    for span in screenSpans {
      XCTAssertNotNil(span.attributes.first { $0.key == "screen.name" }?.value.stringValue)
      XCTAssertEqual(span.attributes.first { $0.key == "app.screen.type" }?.value.stringValue, "swiftui")
      XCTAssertNotNil(span.attributes.first { $0.key == "user.id" }?.value.stringValue)
    }

    // Check for ContentView span
    let contentViewSpan = screenSpans.first { span in
      span.attributes.contains { $0.key == "screen.name" && $0.value.stringValue == "ContentView" }
    }
    XCTAssertNotNil(contentViewSpan, "ContentView span should exist")

    // Check for LoaderView span
    let loaderViewSpan = screenSpans.first { span in
      span.attributes.contains { $0.key == "screen.name" && $0.value.stringValue == "LoaderView" }
    }
    XCTAssertNotNil(loaderViewSpan, "LoaderView span should exist")
  }

  // MARK: - NSURLSession

  func testNetworkSpansExist() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let networkSpans = spans.filter { $0.scope.name == "NSURLSession" }
    let httpSpans = networkSpans.flatMap(\.spans).filter { $0.name == "HTTP GET" }

    XCTAssertEqual(httpSpans.count, 3, "Should have 3 HTTP GET spans")

    // Check for 200 request
    let span200 = httpSpans.first { span in
      span.attributes.contains { $0.key == "http.url" && $0.value.stringValue == "http://localhost:8181/200" }
    }
    XCTAssertNotNil(span200, "HTTP 200 span should exist")

    // Check for 404 request
    let span404 = httpSpans.first { span in
      span.attributes.contains { $0.key == "http.url" && $0.value.stringValue == "http://localhost:8181/404" }
    }
    XCTAssertNotNil(span404, "HTTP 404 span should exist")

    // Check for 500 request
    let span500 = httpSpans.first { span in
      span.attributes.contains { $0.key == "http.url" && $0.value.stringValue == "http://localhost:8181/500" }
    }
    XCTAssertNotNil(span500, "HTTP 500 span should exist")
  }

  func testNetworkSpanAttributes() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let networkSpans = spans.filter { $0.scope.name == "NSURLSession" }
    let httpSpans = networkSpans.flatMap(\.spans).filter { $0.name == "HTTP GET" }

    for span in httpSpans {
      XCTAssertEqual(span.attributes.first { $0.key == "http.method" }?.value.stringValue, "GET")
      XCTAssertNotNil(span.attributes.first { $0.key == "http.url" }?.value.stringValue)
      XCTAssertEqual(span.attributes.first { $0.key == "http.scheme" }?.value.stringValue, "http")
      XCTAssertNotNil(span.attributes.first { $0.key == "http.target" }?.value.stringValue)
      XCTAssertNotNil(span.attributes.first { $0.key == "http.status_code" }?.value.intValue)
      XCTAssertEqual(span.attributes.first { $0.key == "net.peer.name" }?.value.stringValue, "localhost")
      XCTAssertEqual(span.attributes.first { $0.key == "net.peer.port" }?.value.intValue, "8181")
      XCTAssertNotNil(span.attributes.first { $0.key == "network.connection.type" }?.value.stringValue)
      XCTAssertNotNil(span.attributes.first { $0.key == "user.id" }?.value.stringValue)
      XCTAssertNotNil(span.attributes.first { $0.key == "screen.name" }?.value.stringValue)
    }
  }

  // MARK: - Resource Attributes Tests

  func testResourceAttributes() {
    guard let firstTrace = data?.traces.first?.resourceSpans.first else {
      XCTFail("No trace data found")
      return
    }

    let attributes = firstTrace.resource.attributes

    XCTAssertEqual(attributes.first { $0.key == "service.name" }?.value.stringValue, "SimpleAwsDemo")
    XCTAssertEqual(attributes.first { $0.key == "service.version" }?.value.stringValue, "1.0.0")
    XCTAssertEqual(attributes.first { $0.key == "cloud.region" }?.value.stringValue, "us-east-1")
    XCTAssertEqual(attributes.first { $0.key == "aws.rum.appmonitor.id" }?.value.stringValue, "test-app-monitor-id")
    XCTAssertEqual(attributes.first { $0.key == "os.name" }?.value.stringValue, "iOS")
    XCTAssertNotNil(attributes.first { $0.key == "device.model.name" }?.value.stringValue)
  }
}
