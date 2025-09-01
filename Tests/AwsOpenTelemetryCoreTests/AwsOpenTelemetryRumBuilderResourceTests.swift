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
@testable import AwsOpenTelemetryCore

final class AwsOpenTelemetryRumBuilderResourceTests: XCTestCase {
  func testBuildResourceMinimal() {
    let config = AwsOpenTelemetryConfig(aws: AwsConfig(region: "us-east-1", rumAppMonitorId: "test-id"))

    let resource = AwsOpenTelemetryRumBuilder.buildResource(config: config)

    XCTAssertEqual(resource.attributes[AwsAttributes.rumAppMonitorId.rawValue]?.description, "test-id")
    XCTAssertEqual(resource.attributes["cloud.region"]?.description, "us-east-1")
    XCTAssertEqual(resource.attributes["cloud.provider"]?.description, "aws")
    XCTAssertEqual(resource.attributes["cloud.platform"]?.description, "aws_rum")
    XCTAssertNil(resource.attributes[AwsAttributes.rumAppMonitorAlias.rawValue])
  }

  func testBuildResourceFullyCustomized() {
    let config = AwsOpenTelemetryConfig(
      aws: AwsConfig(region: "us-west-2", rumAppMonitorId: "custom-id", rumAlias: "prod-alias"),
      exportOverride: ExportOverride(logs: "http://localhost:4318/v1/logs", traces: "http://localhost:4318/v1/traces"),
      sessionTimeout: 3600,
      debug: true
    )

    let resource = AwsOpenTelemetryRumBuilder.buildResource(config: config)

    XCTAssertEqual(resource.attributes[AwsAttributes.rumAppMonitorId.rawValue]?.description, "custom-id")
    XCTAssertEqual(resource.attributes[AwsAttributes.rumAppMonitorAlias.rawValue]?.description, "prod-alias")
    XCTAssertEqual(resource.attributes["cloud.region"]?.description, "us-west-2")
    XCTAssertEqual(resource.attributes["cloud.provider"]?.description, "aws")
    XCTAssertEqual(resource.attributes["cloud.platform"]?.description, "aws_rum")
  }
}
