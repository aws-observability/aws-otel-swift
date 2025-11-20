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

  // MARK: - software.amazon.opentelemetry.session

  func testSessionStartLogExists() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []
    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionStartLog = sessionLogs.flatMap(\.logRecords).first { $0.eventName == "session.start" }

    XCTAssertNotNil(sessionStartLog, "Session start log should exist")
  }

  func testSessionIdConsistency() {
    let logs = data?.logs.flatMap { $0.resourceLogs.flatMap(\.scopeLogs) } ?? []

    let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
    let sessionStartLog = sessionLogs.flatMap(\.logRecords).first { $0.eventName == "session.start" }

    guard let currentSessionId = sessionStartLog?.attributes.first(where: { $0.key == "session.id" })?.value.stringValue,
          let sessionStartTime = sessionStartLog?.timeUnixNano,
          let sessionStartTimeNano = UInt64(sessionStartTime) else {
      XCTFail("Session start log should have session.id and timestamp")
      return
    }

    // All logs after session start should have the same session.id
    for logRoot in data?.logs ?? [] {
      for resourceLog in logRoot.resourceLogs {
        for scopeLog in resourceLog.scopeLogs {
          for logRecord in scopeLog.logRecords {
            if let sessionId = logRecord.attributes.first(where: { $0.key == "session.id" })?.value.stringValue,
               let logTime = UInt64(logRecord.timeUnixNano),
               logTime >= sessionStartTimeNano {
              XCTAssertEqual(sessionId, currentSessionId, "All logs after session start should have consistent session.id")
            }
          }
        }
      }
    }

    // All spans after session start should have the same session.id
    for traceRoot in data?.traces ?? [] {
      for resourceSpan in traceRoot.resourceSpans {
        for scopeSpan in resourceSpan.scopeSpans {
          for span in scopeSpan.spans {
            if let sessionId = span.attributes.first(where: { $0.key == "session.id" })?.value.stringValue,
               let spanStartTime = UInt64(span.startTimeUnixNano),
               spanStartTime >= sessionStartTimeNano {
              XCTAssertEqual(sessionId, currentSessionId, "All spans after session start should have consistent session.id")
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

  // func testSessionEndLogExists() {
  //   let logs = data?.logs.flatMap { $0.resourceLogs.flatMap { $0.scopeLogs } } ?? []
  //   let sessionLogs = logs.filter { $0.scope.name == "software.amazon.opentelemetry.session" }
  //   let sessionEndLog = sessionLogs.flatMap { $0.logRecords }.first { $0.eventName == "session.end" }

  //   XCTAssertNotNil(sessionEndLog, "Session end log should exist")
  //   XCTAssertTrue(sessionEndLog?.attributes.contains { $0.key == "session.id" } ?? false)
  //   XCTAssertTrue(sessionEndLog?.attributes.contains { $0.key == "user.id" } ?? false)
  // }

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
