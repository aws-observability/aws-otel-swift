import XCTest
@testable import AwsOpenTelemetryCore

class HangTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // Verifies app hang detection with crash report and timing
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
}
