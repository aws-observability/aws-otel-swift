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
import OpenTelemetrySdk
@testable import AwsOpenTelemetryCore
@testable import TestUtils

final class AwsOpenTelemetryRumBuilderResourceTests: XCTestCase {
  func testBuildResourceMinimal() {
    let config = AwsOpenTelemetryConfig(aws: AwsConfig(region: "us-east-1", rumAppMonitorId: "test-id"))
    let resource = AwsResourceBuilder.buildResource(config: config)
    XCTAssertEqual(resource.attributes[AwsAttributes.rumAppMonitorId.rawValue]?.description, "test-id")
    XCTAssertEqual(resource.attributes["cloud.region"]?.description, "us-east-1")
    XCTAssertEqual(resource.attributes["cloud.provider"]?.description, "aws")
    XCTAssertEqual(resource.attributes["cloud.platform"]?.description, "aws_rum")
    XCTAssertEqual(resource.attributes[AwsAttributes.rumSdkVersion.rawValue]?.description, AwsOpenTelemetryAgent.version)
    XCTAssertNotNil(resource.attributes["device.model.name"])
  }

  func testBuildResourceFullyCustomized() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "custom-id", rumAlias: "prod-alias"),
      exportOverride: ExportOverride(logs: "http://localhost:4318/v1/logs", traces: "http://localhost:4318/v1/traces"),
      sessionTimeout: 3600,
      debug: true
    )
    let resource = AwsResourceBuilder.buildResource(config: config)
    XCTAssertEqual(resource.attributes[AwsAttributes.rumAppMonitorId.rawValue]?.description, "custom-id")
    XCTAssertEqual(resource.attributes["cloud.region"]?.description, "us-west-2")
    XCTAssertEqual(resource.attributes["cloud.provider"]?.description, "aws")
    XCTAssertEqual(resource.attributes["cloud.platform"]?.description, "aws_rum")
    XCTAssertEqual(resource.attributes[AwsAttributes.rumSdkVersion.rawValue]?.description, AwsOpenTelemetryAgent.version)
    XCTAssertNotNil(resource.attributes["device.model.name"])
  }

  func testBuildResourceIncludesUpstreamAttributes() {
    let config = AwsOpenTelemetryConfig(aws: AwsConfig(region: "us-east-1", rumAppMonitorId: "test-id"))
    let resource = AwsResourceBuilder.buildResource(config: config)
    XCTAssertEqual(resource.attributes["telemetry.sdk.name"]?.description, "opentelemetry")
    XCTAssertEqual(resource.attributes["telemetry.sdk.language"]?.description, "swift")
    XCTAssertNotNil(resource.attributes["telemetry.sdk.version"])
    XCTAssertNotNil(resource.attributes["service.name"])
    XCTAssertNotNil(resource.attributes["service.version"])
    XCTAssertNotNil(resource.attributes["os.name"])
    XCTAssertNotNil(resource.attributes["os.version"])
    XCTAssertNotNil(resource.attributes["os.type"])
    XCTAssertNotNil(resource.attributes["os.description"])
    XCTAssertNotNil(resource.attributes["device.model.name"])
  }

  func testSpansCreatedWithResource() {
    let spanExporter = InMemorySpanExporter()
    let resource = AwsResourceBuilder.buildResource(
      config: AwsOpenTelemetryConfig(aws: AwsConfig(region: "us-east-1", rumAppMonitorId: "test-id"))
    )

    let tracerProvider = TracerProviderBuilder()
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: spanExporter))
      .with(resource: resource)
      .build()

    let tracer = tracerProvider.get(instrumentationName: "test")
    let span = tracer.spanBuilder(spanName: "test-span").startSpan()
    span.end()

    tracerProvider.forceFlush(timeout: 1.0)

    let exportedSpans = spanExporter.getExportedSpans()
    XCTAssertEqual(exportedSpans.count, 1)

    let spanData = exportedSpans[0]
    XCTAssertEqual(spanData.resource.attributes[AwsAttributes.rumAppMonitorId.rawValue]?.description, "test-id")
    XCTAssertEqual(spanData.resource.attributes["cloud.region"]?.description, "us-east-1")
    XCTAssertNotNil(spanData.resource.attributes["device.model.name"])
  }

  func testLogRecordsCreatedWithResource() {
    let logExporter = InMemoryLogExporter()
    let resource = AwsResourceBuilder.buildResource(
      config: AwsOpenTelemetryConfig(aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "log-test-id"))
    )

    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
      .with(resource: resource)
      .build()

    let logger = loggerProvider.get(instrumentationScopeName: "test")
    logger.logRecordBuilder().setEventName("test name").setBody(AttributeValue.string("test body")).emit()

    let exportedLogs = logExporter.getExportedLogs()
    XCTAssertEqual(exportedLogs.count, 1)

    let logRecord = exportedLogs[0]
    XCTAssertEqual(logRecord.eventName, "test name")
    XCTAssertEqual(logRecord.body, AttributeValue.string("test body"))
    XCTAssertEqual(logRecord.resource.attributes[AwsAttributes.rumAppMonitorId.rawValue]?.description, "log-test-id")
    XCTAssertEqual(logRecord.resource.attributes["cloud.region"]?.description, "us-west-2")
    XCTAssertNotNil(logRecord.resource.attributes["device.model.name"])
  }
}
