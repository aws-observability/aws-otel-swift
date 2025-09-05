import XCTest
@testable import AwsOpenTelemetryCore

final class AppHangTests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData

  func testAppHangLogIsCreated() {
    XCTAssertEqual(true, true)

    let scopeSpans: [ScopeSpan] = data?.traces.flatMap { trace in
      trace.resourceSpans.flatMap { resourceSpan in
        resourceSpan.scopeSpans.filter { scopeSpan in
          scopeSpan.scope.name == AwsInstrumentationScopes.HANG_DIAGNOSTIC
        }
      }
    } ?? []

    let spans = scopeSpans.flatMap { scopeSpan in
      scopeSpan.spans.filter { span in
        span.name == "hang"
      }
    }

    // Assert spans collection is not empty
    XCTAssertFalse(spans.isEmpty, "Spans collection should not be empty")

    let allSpansHaveStackTrace = spans.allSatisfy { span in
      span.attributes.contains { attr in
        attr.key == AwsMetricKitConstants.hangCallStackTree
      }
    }
    XCTAssertTrue(allSpansHaveStackTrace)

    let hasOnFinishStackTrace = spans.contains { span in
      span.attributes.contains { attr in
        attr.key == AwsMetricKitConstants.hangDuration
      }
    }
    XCTAssertTrue(hasOnFinishStackTrace)
  }
}
