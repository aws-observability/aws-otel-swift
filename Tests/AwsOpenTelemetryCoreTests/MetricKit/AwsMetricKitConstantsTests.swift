import XCTest
@testable import AwsOpenTelemetryCore

final class AwsMetricKitConstantsTests: XCTestCase {
  func testCrashesScope() {
    XCTAssertEqual(AwsMetricKitConstants.CRASHES_SCOPE, "aws-otel-swift.crash")
  }
}
