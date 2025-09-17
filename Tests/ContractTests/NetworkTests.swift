import XCTest
@testable import AwsOpenTelemetryCore

class NetworkTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData
  private let HTTP_REQUEST_METHOD_ATTR = "http.method"
  private let STATUS_CODE_ATTR = "http.status_code"
  private let URL_FULL = "http.url"
  private let SERVER_ADDR_ATTR = "net.peer.name"
  private let SERVER_PORT_ATTR = "net.peer.port"
  private let HTTP_200_URL = "http://localhost:8181/200"
  private let HTTP_404_URL = "http://localhost:8181/404"
  private let HTTP_500_URL = "http://localhost:8181/500"

  func testNetworkSpansExistForGET() {
    let scopeSpans: [ScopeSpan] = data?.traces.flatMap { trace in
      trace.resourceSpans.flatMap { resourceSpan in
        resourceSpan.scopeSpans.filter { scopeSpan in
          scopeSpan.scope.name == AwsInstrumentationScopes.URL_SESSION
        }
      }
    } ?? []

    let spans: [Span] = scopeSpans.flatMap { scopeSpan in
      scopeSpan.spans.filter { span in
        span.name == "HTTP GET"
      }
    }

    // Assert spans collection is not empty
    XCTAssertFalse(spans.isEmpty, "Spans collection should not be empty")

    // Check for GET method
    let hasGetMethod = spans.contains { span in
      let methodAttribute = span.attributes.first { attr in
        attr.key == HTTP_REQUEST_METHOD_ATTR
      }

      if let attr = methodAttribute {
        return attr.value.stringValue == "GET"
      }
      return false
    }

    XCTAssertTrue(hasGetMethod)

    // Check server address exists
    let serverAddr = spans.first?.attributes.first { attr in
      attr.key == SERVER_ADDR_ATTR
    }
    XCTAssertNotNil(serverAddr?.value.stringValue)

    // Check server port exists
    let serverPort = spans.first?.attributes.first { attr in
      attr.key == SERVER_PORT_ATTR
    }
    XCTAssertNotNil(serverPort?.value.intValue)
  }

  func testNetworkSpansExistFor200() {
    let scopeSpans: [ScopeSpan] = data?.traces.flatMap { trace in
      trace.resourceSpans.flatMap { resourceSpan in
        resourceSpan.scopeSpans.filter { scopeSpan in
          scopeSpan.scope.name == AwsInstrumentationScopes.URL_SESSION
        }
      }
    } ?? []

    let spans: [Span] = scopeSpans.flatMap { scopeSpan in
      scopeSpan.spans.filter { span in
        span.name == "HTTP GET"
      }
    }

    // Check for status code
    let hasStatusCode = spans.contains { span in
      let statusCodeAttribute = span.attributes.first { attr in
        attr.key == STATUS_CODE_ATTR
      }
      return statusCodeAttribute != nil
    }

    XCTAssertTrue(hasStatusCode)

    // Check for HTTP 200 URL
    let has200URL = spans.contains { span in
      let urlAttribute = span.attributes.first { attr in
        attr.key == URL_FULL
      }
      return urlAttribute?.value.stringValue == HTTP_200_URL
    }
    XCTAssertTrue(has200URL)

    // Check status code 200
    let spans200 = spans.filter { span in
      let urlAttribute = span.attributes.first { attr in
        attr.key == URL_FULL
      }
      return urlAttribute?.value.stringValue == HTTP_200_URL
    }
    let status200 = spans200.first?.attributes.first { attr in
      attr.key == STATUS_CODE_ATTR
    }
    XCTAssertEqual(status200?.value.intValue, "200")
  }

  // func testNetworkSpansExistFor404() {
  //   let scopeSpans: [ScopeSpan] = data?.traces.flatMap { trace in
  //     trace.resourceSpans.flatMap { resourceSpan in
  //       resourceSpan.scopeSpans.filter { scopeSpan in
  //         scopeSpan.scope.name == AwsInstrumentationScopes.URL_SESSION
  //       }
  //     }
  //   } ?? []

  //   let spans: [Span] = scopeSpans.flatMap { scopeSpan in
  //     scopeSpan.spans.filter { span in
  //       span.name == "HTTP GET"
  //     }
  //   }

  //   // Check for status code
  //   let hasStatusCode = spans.contains { span in
  //     let statusCodeAttribute = span.attributes.first { attr in
  //       attr.key == STATUS_CODE_ATTR
  //     }
  //     return statusCodeAttribute != nil
  //   }

  //   XCTAssertTrue(hasStatusCode)

  //   // Check for HTTP 404 URL
  //   let has404URL = spans.contains { span in
  //     let urlAttribute = span.attributes.first { attr in
  //       attr.key == URL_FULL
  //     }
  //     return urlAttribute?.value.stringValue == HTTP_404_URL
  //   }
  //   XCTAssertTrue(has404URL)

  //   // Check status code 404
  //   let spans404 = spans.filter { span in
  //     let urlAttribute = span.attributes.first { attr in
  //       attr.key == URL_FULL
  //     }
  //     return urlAttribute?.value.stringValue == HTTP_404_URL
  //   }
  //   let status404 = spans404.first?.attributes.first { attr in
  //     attr.key == STATUS_CODE_ATTR
  //   }
  //   XCTAssertEqual(status404?.value.intValue, "404")

  // }

  func testNetworkSpansExistFor500() {
    let scopeSpans: [ScopeSpan] = data?.traces.flatMap { trace in
      trace.resourceSpans.flatMap { resourceSpan in
        resourceSpan.scopeSpans.filter { scopeSpan in
          scopeSpan.scope.name == AwsInstrumentationScopes.URL_SESSION
        }
      }
    } ?? []

    let spans: [Span] = scopeSpans.flatMap { scopeSpan in
      scopeSpan.spans.filter { span in
        span.name == "HTTP GET"
      }
    }

    // Check for status code
    let hasStatusCode = spans.contains { span in
      let statusCodeAttribute = span.attributes.first { attr in
        attr.key == STATUS_CODE_ATTR
      }
      return statusCodeAttribute != nil
    }

    XCTAssertTrue(hasStatusCode)

    // Check for HTTP 500 URL
    let has500URL = spans.contains { span in
      let urlAttribute = span.attributes.first { attr in
        attr.key == URL_FULL
      }
      return urlAttribute?.value.stringValue == HTTP_500_URL
    }
    XCTAssertTrue(has500URL)

    // Check status code 500
    let spans500 = spans.filter { span in
      let urlAttribute = span.attributes.first { attr in
        attr.key == URL_FULL
      }
      return urlAttribute?.value.stringValue == HTTP_500_URL
    }
    let status500 = spans500.first?.attributes.first { attr in
      attr.key == STATUS_CODE_ATTR
    }
    XCTAssertEqual(status500?.value.intValue, "500")
  }
}
