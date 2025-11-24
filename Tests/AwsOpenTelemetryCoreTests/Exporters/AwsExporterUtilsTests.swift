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

class AwsExporterUtilsTests: XCTestCase {
  func testRumEndpointWithUsEast1() {
    let endpoint = AwsExporterUtils.rumEndpoint(region: "us-east-1")
    XCTAssertEqual(endpoint, "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum")
  }

  func testRumEndpointWithApSoutheast1() {
    let endpoint = AwsExporterUtils.rumEndpoint(region: "ap-southeast-1")
    XCTAssertEqual(endpoint, "https://dataplane.rum.ap-southeast-1.amazonaws.com/v1/rum")
  }
}
