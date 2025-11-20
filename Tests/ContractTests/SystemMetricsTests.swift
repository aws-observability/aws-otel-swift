import XCTest
@testable import AwsOpenTelemetryCore

class SystemMetricsTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // Verifies all events include memory and CPU usage metrics
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
}
