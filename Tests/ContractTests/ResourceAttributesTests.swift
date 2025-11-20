import XCTest
@testable import AwsOpenTelemetryCore

class ResourceAttributesTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // Verifies telemetry data includes correct service and device metadata
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
