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
    XCTAssertEqual(userInfo?[AwsSessionConstants.id], "cache-session-id")
    XCTAssertEqual(userInfo?[AwsSessionConstants.previousId], "cache-prev-id")
    XCTAssertNotNil(userInfo?["user.id"])
  }

  func testReporterConfiguration() {
    XCTAssertNotNil(KSCrashInstrumentation.reporter)
    XCTAssertFalse(KSCrashInstrumentation.isInstalled)
  }

  func testMaxStackTraceBytes() {
    XCTAssertEqual(KSCrashInstrumentation.maxStackTraceBytes, 30 * 1024)
  }

  func testExtractCrashMessage() {
    let stackTrace = """
    Incident Identifier: 599E8CAF-9D3E-4208-BC3D-C8DA6160CF29
    CrashReporter Key:   555427bbb1413d491a71026e2bdda7a55fb6dfcc
    Hardware Model:      iPhone17,2
    Process:             AwsHackerNewsDemo [27205]
    Path:                /private/var/containers/Bundle/Application/70705CFF-805B-41DB-B1A2-D3836B7471D6/AwsHackerNewsDemo.app/AwsHackerNewsDemo
    Identifier:          Billy-Dev
    Version:             1.0 (6)
    Code Type:           ARM-64 (Native)
    Role:                Foreground
    Parent Process:      launchd [1]

    Date/Time:           2025-10-28 13:18:08.595 -0700
    OS Version:          iOS 18.6.2 (22G100)
    Report Version:      104

    Exception Type:  EXC_BREAKPOINT (SIGTRAP)
    Exception Codes: KERN_INVALID_ADDRESS at 0x000000019ed5c8c4
    Triggered by Thread:  0

    Thread 0 Crashed:
    0   libswiftCore.dylib            \t0x000000019ed5c8c4 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172
    1   libswiftCore.dylib            \t0x000000019ed5c8c4 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172
    2   AwsHackerNewsDemo             \t0x00000001009825f0 __swift_instantiateConcreteTypeFromMangledNameAbstract + 42572

    Thread 1:
    0   libsystem_kernel.dylib        \t0x00000001f14e1a90 __workq_kernreturn + 8
    1   libsystem_pthread.dylib       \t0x000000022ab30a58 _pthread_wqthread + 368
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)

    XCTAssertNotNil(result)
    XCTAssertEqual(result, "Crash detected on thread 0 at libswiftCore.dylib 0x000000019ed5c8c4 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172")
  }

  func testExtractCrashMessageWithNoThreadCrashed() {
    let stackTrace = """
    Some other content
    Thread 1:
    0   libsystem_kernel.dylib        \t0x00000001f14e1a90 __workq_kernreturn + 8
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)

    XCTAssertEqual(result, "Crash detected at unknown location")
  }

  func testExtractCrashMessageWithDifferentThreadNumber() {
    let stackTrace = """
    Thread 5 Crashed:
    0   SomeFramework                 \t0x00000001f14e1a90 someFunction + 8
    1   AnotherFramework              \t0x000000022ab30a58 anotherFunction + 368
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)

    XCTAssertNotNil(result)
    XCTAssertEqual(result, "Crash detected on thread 5 at SomeFramework 0x00000001f14e1a90 someFunction + 8")
  }

  func testRecoverCrashContextSuccess() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = [
      "exception.type": AttributeValue.string("crash"),
      "recovered_context": AttributeValue.bool(false)
    ]

    let rawCrash: [String: Any] = [
      "report": [
        "timestamp": "2025-10-28T21:38:55.554842Z"
      ],
      "user": [
        AwsSessionConstants.id: "test-session-id",
        AwsSessionConstants.previousId: "test-prev-session-id",
        "user.id": "test-user-id"
      ]
    ]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result["recovered_context"]?.description, "true")
    XCTAssertEqual(result[AwsSessionConstants.id]?.description, "test-session-id")
    XCTAssertEqual(result[AwsSessionConstants.previousId]?.description, "test-prev-session-id")
    XCTAssertEqual(result["user.id"]?.description, "test-user-id")
  }

  func testRecoverCrashContextMissingReport() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = [
      "recovered_context": AttributeValue.bool(false)
    ]

    let rawCrash: [String: Any] = [:]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result["recovered_context"]?.description, "false")
    XCTAssertNil(result[AwsSessionConstants.id])
  }

  func testRecoverCrashContextMissingUserInfo() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = [
      "recovered_context": AttributeValue.bool(false)
    ]

    let rawCrash: [String: Any] = [
      "report": [
        "timestamp": "2025-10-28T21:38:55.554842Z"
      ]
    ]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result["recovered_context"]?.description, "false")
    XCTAssertNil(result[AwsSessionConstants.id])
  }

  func testRecoverCrashContextPartialUserInfo() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = [
      "recovered_context": AttributeValue.bool(false)
    ]

    let rawCrash: [String: Any] = [
      "report": [
        "timestamp": "2025-10-28T21:38:55.554842Z"
      ],
      "user": [
        AwsSessionConstants.id: "test-session-id"
        // Missing prev_session_id and user.id
      ]
    ]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result["recovered_context"]?.description, "true")
    XCTAssertEqual(result[AwsSessionConstants.id]?.description, "test-session-id")
    XCTAssertNil(result[AwsSessionConstants.previousId])
    XCTAssertNil(result["user.id"])
  }
}

class MockLogRecordBuilder: LogRecordBuilder {
  var timestamp: Date?

  func setTimestamp(_ timestamp: Date) -> LogRecordBuilder {
    self.timestamp = timestamp
    return self
  }

  func setObservedTimestamp(_ timestamp: Date) -> LogRecordBuilder { self }
  func setEventName(_ name: String) -> LogRecordBuilder { self }
  func setSeverity(_ severity: Severity) -> LogRecordBuilder { self }
  func setBody(_ body: AttributeValue) -> LogRecordBuilder { self }
  func setAttributes(_ attributes: [String: AttributeValue]) -> LogRecordBuilder { self }
  func addAttribute(key: String, value: AttributeValue) -> LogRecordBuilder { self }
  func emit() {}
}
