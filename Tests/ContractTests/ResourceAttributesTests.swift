import XCTest
@testable import AwsOpenTelemetryCore

class ResourceAttributesTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData
  // Region and app monitor id are whatever the harness was pointed at; everything else asserted here
  // is the same in every mode. See `ContractExpectations` — with no AWS_OTEL_CONTRACT_* set these
  // resolve to the hermetic literals this test has always used.
  private let expected = ContractExpectations.current

  // Verifies telemetry data includes correct service and device metadata
  func testResourceAttributes() {
    guard let firstTrace = data?.traces.first?.resourceSpans.first else {
      XCTFail("No trace data found")
      return
    }

    let attributes = firstTrace.resource.attributes

    XCTAssertEqual(attributes.first { $0.key == "service.name" }?.value.stringValue, "SimpleAwsDemo")
    XCTAssertEqual(attributes.first { $0.key == "service.version" }?.value.stringValue, "1.0.0")
    XCTAssertEqual(attributes.first { $0.key == "cloud.region" }?.value.stringValue, expected.region)
    // Deliberately compared without being printed on failure: against a real endpoint this is the
    // app monitor id, which is a secret. XCTAssertEqual would echo both values into the log, so the
    // comparison is made first and only the outcome is reported.
    let actualAppMonitorId = attributes.first { $0.key == "aws.rum.appmonitor.id" }?.value.stringValue
    XCTAssertTrue(
      actualAppMonitorId == expected.appMonitorId,
      "aws.rum.appmonitor.id did not match the id the harness configured."
        + " Values withheld — against a real endpoint this attribute is a secret."
        + " (expected \(expected.appMonitorId.count) chars, got \(actualAppMonitorId?.count.description ?? "no attribute"))"
    )
    XCTAssertEqual(attributes.first { $0.key == "os.name" }?.value.stringValue, "iOS")
    XCTAssertNotNil(attributes.first { $0.key == "device.model.name" }?.value.stringValue)
  }
}
