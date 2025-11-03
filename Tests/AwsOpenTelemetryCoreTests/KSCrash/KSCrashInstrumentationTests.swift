/*
 * Copyright Amazon.com, Inc. or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import XCTest
import OpenTelemetrySdk
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import TestUtils

#if canImport(KSCrash)
  import KSCrash
#endif

final class KSCrashInstrumentationTests: XCTestCase {
  private var inMemoryExporter: InMemoryLogExporter!

  override func setUp() {
    super.setUp()
    inMemoryExporter = InMemoryLogExporter.register()
  }

  override func tearDown() {
    inMemoryExporter.reset()
    NotificationCenter.default.removeObserver(self)
    super.tearDown()
  }

  func testCacheCrashContext() {
    let session = AwsSession(
      id: "cache-session-id",
      expireTime: Date(timeIntervalSinceNow: 1800),
      previousId: "cache-prev-id"
    )

    KSCrashInstrumentation.cacheCrashContext(session: session)

    let userInfo = KSCrashInstrumentation.reporter.userInfo as? [String: String]
    XCTAssertEqual(userInfo?[AwsSessionSemConv.id], "cache-session-id")
    XCTAssertEqual(userInfo?[AwsSessionSemConv.previousId], "cache-prev-id")
    XCTAssertNotNil(userInfo?["user.id"])
  }

  func testReporterConfiguration() {
    XCTAssertNotNil(KSCrashInstrumentation.reporter)
  }

  func testMaxStackTraceBytes() {
    XCTAssertEqual(KSCrashInstrumentation.maxStackTraceBytes, 30 * 1024)
  }

  func testExtractCrashMessage() {
    let stackTrace = """
    Thread 0 Crashed:
    0   libswiftCore.dylib            \t0x000000019ed5c8c4 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172
    1   libswiftCore.dylib            \t0x000000019ed5c8c4 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "Crash detected on thread 0 at libswiftCore.dylib 0x000000019ed5c8c4 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172")
  }

  func testExtractCrashMessageWithDifferentThreadNumber() {
    let stackTrace = """
    Thread 5 Crashed:
    0   SomeFramework                 \t0x00000001f14e1a90 someFunction + 8
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "Crash detected on thread 5 at SomeFramework 0x00000001f14e1a90 someFunction + 8")
  }

  func testExtractCrashMessageEdgeCases() {
    XCTAssertEqual(KSCrashInstrumentation.extractCrashMessage(from: ""), "Crash detected at unknown location")
    XCTAssertEqual(KSCrashInstrumentation.extractCrashMessage(from: "Thread Crashed:\n0   SomeFramework"), "Crash detected at unknown location")

    let noThreadCrashed = "Some other content\nThread 1:\n0   libsystem_kernel.dylib"
    XCTAssertEqual(KSCrashInstrumentation.extractCrashMessage(from: noThreadCrashed), "Crash detected at unknown location")
  }

  func testExtractCrashMessageWithWhitespaceHandling() {
    let stackTrace = """
    Thread 2 Crashed:
    0     MyFramework     \t\t\t    0x123456789    myFunction    +    123
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "Crash detected on thread 2 at MyFramework 0x123456789 myFunction + 123")
  }

  func testRecoverCrashContextSuccess() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = [
      "exception.type": AttributeValue.string("crash"),
      "recovered_context": AttributeValue.bool(false)
    ]

    let rawCrash: [String: Any] = [
      "report": ["timestamp": "2025-10-28T21:38:55.554842Z"],
      "user": [
        AwsSessionSemConv.id: "test-session-id",
        AwsSessionSemConv.previousId: "test-prev-session-id",
        "user.id": "test-user-id"
      ]
    ]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result["recovered_context"]?.description, "true")
    XCTAssertEqual(result[AwsSessionSemConv.id]?.description, "test-session-id")
    XCTAssertEqual(result[AwsSessionSemConv.previousId]?.description, "test-prev-session-id")
    XCTAssertEqual(result["user.id"]?.description, "test-user-id")
  }

  func testRecoverCrashContextFailureCases() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = ["recovered_context": AttributeValue.bool(false)]

    var result = KSCrashInstrumentation.recoverCrashContext(from: [:], log: mockLogBuilder, attributes: initialAttributes)
    XCTAssertEqual(result["recovered_context"]?.description, "false")
    XCTAssertNil(result[AwsSessionSemConv.id])

    let crashWithoutUser = ["report": ["timestamp": "2025-10-28T21:38:55.554842Z"]]
    result = KSCrashInstrumentation.recoverCrashContext(from: crashWithoutUser, log: mockLogBuilder, attributes: initialAttributes)
    XCTAssertEqual(result["recovered_context"]?.description, "false")

    let crashWithInvalidTimestamp = [
      "report": ["timestamp": "invalid-timestamp"],
      "user": [AwsSessionSemConv.id: "test-session-id"]
    ]
    result = KSCrashInstrumentation.recoverCrashContext(from: crashWithInvalidTimestamp, log: mockLogBuilder, attributes: initialAttributes)
    XCTAssertEqual(result["recovered_context"]?.description, "false")
  }

  func testRecoverCrashContextPartialUserInfo() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = ["recovered_context": AttributeValue.bool(false)]

    let rawCrash: [String: Any] = [
      "report": ["timestamp": "2025-10-28T21:38:55.554842Z"],
      "user": [AwsSessionSemConv.id: "test-session-id"]
    ]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result["recovered_context"]?.description, "true")
    XCTAssertEqual(result[AwsSessionSemConv.id]?.description, "test-session-id")
    XCTAssertNil(result[AwsSessionSemConv.previousId])
    XCTAssertNil(result["user.id"])
  }

  func testRecoverCrashContextWithOptionalFields() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = ["recovered_context": AttributeValue.bool(false)]

    let rawCrash: [String: Any] = [
      "report": ["timestamp": "2025-10-28T21:38:55.554842Z"],
      "user": [
        AwsSessionSemConv.id: "test-session-id",
        AwsViewSemConv.screenName: "TestScreen"
      ]
    ]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result["recovered_context"]?.description, "true")
    XCTAssertEqual(result[AwsViewSemConv.screenName]?.description, "TestScreen")
  }

  func testCacheCrashContextVariations() {
    KSCrashInstrumentation.cacheCrashContext(session: nil, userId: nil, screenName: nil)
    var userInfo = KSCrashInstrumentation.reporter.userInfo as? [String: String]
    XCTAssertNotNil(userInfo?[AwsSessionSemConv.id])
    XCTAssertNotNil(userInfo?[AwsUserSemvConv.id])

    let session = AwsSession(id: "specific-session", expireTime: Date(timeIntervalSinceNow: 1800))
    KSCrashInstrumentation.cacheCrashContext(session: session, userId: "specific-user", screenName: "SpecificScreen")
    userInfo = KSCrashInstrumentation.reporter.userInfo as? [String: String]
    XCTAssertEqual(userInfo?[AwsSessionSemConv.id], "specific-session")
    XCTAssertEqual(userInfo?[AwsUserSemvConv.id], "specific-user")
    XCTAssertEqual(userInfo?[AwsViewSemConv.screenName], "SpecificScreen")
  }

  func testNotificationHandling() {
    KSCrashInstrumentation.setupNotificationObservers()
    defer {
      for observer in KSCrashInstrumentation.observers {
        NotificationCenter.default.removeObserver(observer)
      }
      KSCrashInstrumentation.observers.removeAll()
    }

    let session = AwsSession(id: "notification-session", expireTime: Date(timeIntervalSinceNow: 1800))
    NotificationCenter.default.post(name: SessionStartNotification, object: session)

    let expectation = XCTestExpectation(description: "Async crash context update")
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    let userInfo = KSCrashInstrumentation.reporter.userInfo as? [String: String]
    XCTAssertEqual(userInfo?[AwsSessionSemConv.id], "notification-session")
  }

  func testInstallMethod() {
    XCTAssertNoThrow(KSCrashInstrumentation.install())
  }

  func testProcessStoredCrashes() {
    XCTAssertNoThrow(KSCrashInstrumentation.processStoredCrashes())
  }
}

class MockLogRecordBuilder: LogRecordBuilder {
  var timestamp: Date?
  var attributes: [String: AttributeValue] = [:]
  var eventName: String?

  func setTimestamp(_ timestamp: Date) -> LogRecordBuilder {
    self.timestamp = timestamp
    return self
  }

  func setObservedTimestamp(_ timestamp: Date) -> LogRecordBuilder { return self }
  func setEventName(_ name: String) -> LogRecordBuilder {
    eventName = name
    return self
  }

  func setSeverity(_ severity: Severity) -> LogRecordBuilder { return self }
  func setBody(_ body: AttributeValue) -> LogRecordBuilder { return self }
  func setAttributes(_ attributes: [String: AttributeValue]) -> LogRecordBuilder {
    self.attributes = attributes
    return self
  }

  func addAttribute(key: String, value: AttributeValue) -> LogRecordBuilder {
    attributes[key] = value
    return self
  }

  func emit() {}
}
