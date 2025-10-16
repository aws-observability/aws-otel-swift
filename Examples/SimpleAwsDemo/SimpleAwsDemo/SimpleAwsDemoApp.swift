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
  private let appMonitorId = "33868e1a-72af-4815-8605-46f5dc76c91b"
  private let region = "us-west-2"

  private func isImportCoreNoInitialization() -> Bool {
    return !ProcessInfo.processInfo.arguments.contains("--importCoreNoInitialization")
  }

  init() {
    setupOpenTelemetry()
  }

  var body: some Scene {
    WindowGroup {
      ContentView(viewModel: LoaderViewModel())
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
      sessionTimeout: 5 * 60,
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
