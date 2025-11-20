import XCTest
@testable import AwsOpenTelemetryCore

class NetworkTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  // Verifies HTTP network requests are tracked as spans
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

  // Verifies network spans contain correct HTTP and system attributes
  func testNetworkSpanAttributes() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let networkSpans = spans.filter { $0.scope.name == "NSURLSession" }
    let httpSpans = networkSpans.flatMap(\.spans).filter { $0.name == "HTTP GET" }

    for span in httpSpans {
      // HTTP attributes
      XCTAssertEqual(span.attributes.first { $0.key == "http.method" }?.value.stringValue, "GET")
      XCTAssertNotNil(span.attributes.first { $0.key == "http.url" }?.value.stringValue)
      XCTAssertEqual(span.attributes.first { $0.key == "http.scheme" }?.value.stringValue, "http")
      XCTAssertNotNil(span.attributes.first { $0.key == "http.target" }?.value.stringValue)
      XCTAssertNotNil(span.attributes.first { $0.key == "http.status_code" }?.value.intValue)
      XCTAssertNotNil(span.attributes.first { $0.key == "http.response.body.size" }?.value.intValue)

      // Network attributes
      XCTAssertEqual(span.attributes.first { $0.key == "net.peer.name" }?.value.stringValue, "localhost")
      XCTAssertEqual(span.attributes.first { $0.key == "net.peer.port" }?.value.intValue, "8181")
      XCTAssertEqual(span.attributes.first { $0.key == "network.connection.type" }?.value.stringValue, "unavailable")

      // Session and user attributes
      XCTAssertNotNil(span.attributes.first { $0.key == "user.id" }?.value.stringValue)
      XCTAssertNotNil(span.attributes.first { $0.key == "session.id" }?.value.stringValue)
      XCTAssertNotNil(span.attributes.first { $0.key == "session.previous_id" }?.value.stringValue)
      XCTAssertEqual(span.attributes.first { $0.key == "screen.name" }?.value.stringValue, "ContentView")

      // System metrics
      XCTAssertNotNil(span.attributes.first { $0.key == "process.cpu.utilization" }?.value.doubleValue)
      XCTAssertNotNil(span.attributes.first { $0.key == "process.memory.usage" }?.value.doubleValue)
    }
  }

  // Verifies specific HTTP status codes and response attributes
  func testNetworkSpanStatusCodes() {
    let spans = data?.traces.flatMap { $0.resourceSpans.flatMap(\.scopeSpans) } ?? []
    let networkSpans = spans.filter { $0.scope.name == "NSURLSession" }
    let httpSpans = networkSpans.flatMap(\.spans).filter { $0.name == "HTTP GET" }

    // Test 200 OK span
    let span200 = httpSpans.first { span in
      span.attributes.contains { $0.key == "http.url" && $0.value.stringValue == "http://localhost:8181/200" }
    }
    XCTAssertNotNil(span200)
    XCTAssertEqual(span200?.attributes.first { $0.key == "http.status_code" }?.value.intValue, "200")
    XCTAssertEqual(span200?.attributes.first { $0.key == "http.target" }?.value.stringValue, "/200")
    XCTAssertEqual(span200?.attributes.first { $0.key == "http.response.body.size" }?.value.intValue, "46")
    XCTAssertNil(span200?.status?.message) // 200 should not have error status

    // Test 404 span
    let span404 = httpSpans.first { span in
      span.attributes.contains { $0.key == "http.url" && $0.value.stringValue == "http://localhost:8181/404" }
    }
    XCTAssertNotNil(span404)
    XCTAssertEqual(span404?.attributes.first { $0.key == "http.status_code" }?.value.intValue, "404")
    XCTAssertEqual(span404?.attributes.first { $0.key == "http.target" }?.value.stringValue, "/404")
    XCTAssertEqual(span404?.attributes.first { $0.key == "http.response.body.size" }?.value.intValue, "78")
    XCTAssertEqual(span404?.status?.message, "404")
    XCTAssertEqual(span404?.status?.code, "STATUS_CODE_ERROR")

    // Test 500 span
    let span500 = httpSpans.first { span in
      span.attributes.contains { $0.key == "http.url" && $0.value.stringValue == "http://localhost:8181/500" }
    }
    XCTAssertNotNil(span500)
    XCTAssertEqual(span500?.attributes.first { $0.key == "http.status_code" }?.value.intValue, "500")
    XCTAssertEqual(span500?.attributes.first { $0.key == "http.target" }?.value.stringValue, "/500")
    XCTAssertEqual(span500?.attributes.first { $0.key == "http.response.body.size" }?.value.intValue, "82")
    XCTAssertEqual(span500?.status?.message, "500")
    XCTAssertEqual(span500?.status?.code, "STATUS_CODE_ERROR")
  }
}
