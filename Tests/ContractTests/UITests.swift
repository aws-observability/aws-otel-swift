import XCTest
@testable import AwsOpenTelemetryCore

class UITests: XCTestCase {
  private let data = OtlpResolver.shared.parsedData
  private let VIEW_CLASS_ATTR = "view.class"
  private let SESSION_ID_ATTR = "session.id"
  private let USER_ID_ATTR = "user.id"
  private let VIEW_NAME_ATTR = "screen.name"
  private let SESSION_PREVIOUS_ID_ATTR = "session.previous_id"

  func testUISpanIsCreated() {
    let scopeSpans: [ScopeSpan] = data?.traces.flatMap { trace in
      trace.resourceSpans.flatMap { resourceSpan in
        resourceSpan.scopeSpans.filter { scopeSpan in
          scopeSpan.scope.name == AwsInstrumentationScopes.UIKIT_VIEW
        }
      }
    } ?? []

    let spans = scopeSpans.flatMap { scopeSpan in
      scopeSpan.spans.filter { span in
        span.name == "view.duration"
      }
    }

    // Assert spans collection is not empty
    XCTAssertFalse(spans.isEmpty, "Spans collection should not be empty")

    // Check for DemoViewController class
    let hasViewClass = spans.contains { span in
      let viewClassAttr = span.attributes.first { attr in
        attr.key == VIEW_CLASS_ATTR
      }
      return viewClassAttr?.value.stringValue == "DemoViewController"
    }
    XCTAssertTrue(hasViewClass)

    // Check for session ID
    let hasSessionId = spans.contains { span in
      let sessionIdAttr = span.attributes.first { attr in
        attr.key == SESSION_ID_ATTR
      }
      return sessionIdAttr?.value != nil
    }
    XCTAssertTrue(hasSessionId)

    // Check for previous session ID
    let hasPreviousSessionId = spans.contains { span in
      let previousSessionIdAttr = span.attributes.first { attr in
        attr.key == SESSION_PREVIOUS_ID_ATTR
      }
      return previousSessionIdAttr?.value != nil
    }
    XCTAssertTrue(hasPreviousSessionId)

    // Check for user ID
    let hasUserId = spans.contains { span in
      let userIdAttr = span.attributes.first { attr in
        attr.key == USER_ID_ATTR
      }
      return userIdAttr?.value != nil
    }
    XCTAssertTrue(hasUserId)

    // Check for view name
    let hasViewName = spans.contains { span in
      let viewNameAttr = span.attributes.first { attr in
        attr.key == VIEW_NAME_ATTR
      }
      return viewNameAttr?.value.stringValue == "DemoViewController"
    }
    XCTAssertTrue(hasViewName)
  }
}
