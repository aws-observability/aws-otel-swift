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

import SwiftUI
import AwsOpenTelemetryCore

@main
struct SimpleAwsDemoApp: App {
  private let cognitoPoolId = "us-east-1:ac7df0bd-a16a-4756-9857-960afb12bd97"
  private let region = "us-east-1"

  init() {
    setupOpenTelemetry()
  }

  var body: some Scene {
    WindowGroup {
      LoaderView(cognitoPoolId: cognitoPoolId, region: region)
    }
  }

  private func setupOpenTelemetry() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: "4e9ea50f-09c2-4297-914d-bcb97d083c3a")
    let exportOverride = ExportOverride(
      logs: "http://localhost:4318/v1/logs",
      traces: "http://localhost:4318/v1/traces"
    )
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      sessionTimeout: 5, // just 5 seconds for demo purposes
      debug: true
    )

    do {
      try AwsOpenTelemetryRumBuilder.create(config: config)
        .build()
    } catch AwsOpenTelemetryConfigError.alreadyInitialized {
      print("SDK is already initialized")
    } catch {
      print("Error initializing SDK: \(error)")
    }
  }
}
