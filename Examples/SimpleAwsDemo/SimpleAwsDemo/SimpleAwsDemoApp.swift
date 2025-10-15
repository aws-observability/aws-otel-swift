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
  private let cognitoPoolId = "us-west-2_jxYFz3SsN"
  private let appMonitorId = "9a49451f-b9d7-4fef-97aa-18896dc5f0b5"
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
      logs: "http://localhost:4318/v1/logs",
      traces: "http://localhost:4318/v1/traces"
    )
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      sessionTimeout: 60,
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
