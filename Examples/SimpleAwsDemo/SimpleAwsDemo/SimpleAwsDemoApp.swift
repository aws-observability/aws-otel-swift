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
  private let cognitoPoolId = "us-west-2:f1d59878-424f-43d4-9c27-0f2553b89ecb"
  private let appMonitorId = "6f39bbcb-b1a5-4b7b-a33b-5fa9e911193d"
  private let region = "us-west-2"

  private func isImportCoreNoInitialization() -> Bool {
    return !ProcessInfo.processInfo.arguments.contains("--importCoreNoInitialization")
  }

  init() {
    if isImportCoreNoInitialization() {
      setupOpenTelemetry()
    }
  }

  var body: some Scene {
    WindowGroup {
      LoaderView(cognitoPoolId: cognitoPoolId, region: region)
    }
  }

  private func setupOpenTelemetry() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let exportOverride = ExportOverride(
      logs: "https://dataplane.rum-gamma.us-west-2.amazonaws.com/v1/rum",
      traces: "https://dataplane.rum-gamma.us-west-2.amazonaws.com/v1/rum"
    )
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
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
