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
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore
@testable import OpenTelemetrySdk

final class AwsDeviceKitLogProcessorTests: XCTestCase {
  var mockNextProcessor: DeviceKitMockLogRecordProcessor!
  var logRecordProcessor: AwsDeviceKitLogProcessor!
  var testLogRecord: ReadableLogRecord!

  override func setUp() {
    super.setUp()
    mockNextProcessor = DeviceKitMockLogRecordProcessor()
    logRecordProcessor = AwsDeviceKitLogProcessor(nextProcessor: mockNextProcessor)

    testLogRecord = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: ["original.key": AttributeValue.string("original.value")]
    )
  }

  func testOnEmitAddsDeviceKitAttributes() {
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 1)
    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    #if os(iOS) || os(tvOS)
      if AwsDeviceKitManager.shared.getBatteryLevel() != nil {
        XCTAssertNotNil(enhancedRecord.attributes[AwsDeviceKitSemConv.batteryCharge])
      }
    #endif

    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
      if AwsDeviceKitManager.shared.getCPUUtil() != nil {
        XCTAssertNotNil(enhancedRecord.attributes[AwsDeviceKitSemConv.cpuUtilization])
      }
      if AwsDeviceKitManager.shared.getMemoryUsage() != nil {
        XCTAssertNotNil(enhancedRecord.attributes[AwsDeviceKitSemConv.memoryUsage])
      }
    #endif
  }

  func testOnEmitPreservesOriginalAttributes() {
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]
    XCTAssertEqual(enhancedRecord.attributes["original.key"], AttributeValue.string("original.value"))
  }

  func testShutdownReturnsSuccess() {
    let result = logRecordProcessor.shutdown(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testForceFlushReturnsSuccess() {
    let result = logRecordProcessor.forceFlush(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }
}

class DeviceKitMockLogRecordProcessor: LogRecordProcessor {
  var receivedLogRecords: [ReadableLogRecord] = []

  func onEmit(logRecord: ReadableLogRecord) {
    receivedLogRecords.append(logRecord)
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
