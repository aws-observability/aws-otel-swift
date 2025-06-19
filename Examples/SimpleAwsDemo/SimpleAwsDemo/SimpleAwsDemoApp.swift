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
import AWSCore
import AwsOpenTelemetryCore

@main
struct SimpleAwsDemoApp: App {
  // Replace these with your actual AWS credentials and configuration
  private let cognitoPoolId = "YOUR_IDENTITY_POOL_ID_FROM_OUTPUT"
  private let awsRegion = "YOUR_REGION_FROM_OUTPUT"

  // Create the AWS service as a StateObject so it persists for the lifetime of the app
  @StateObject private var awsService: AwsService

  // Initialize AWS services
  init() {
    // Create the AWS service
    let service = AwsService(cognitoPoolId: cognitoPoolId, awsRegion: awsRegion)
    _awsService = StateObject(wrappedValue: service)

    // Initialize AWS OpenTelemetry
    setupOpenTelemetry()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(awsService)
    }
  }

  private func setupOpenTelemetry() {
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(
        region: "YOUR_REGION_FROM_OUTPUT",
        appMonitorId: "YOUR_APP_MONITOR_ID_FROM_OUTPUT",
        overrideEndpoint: EndpointOverrides(
          logs: "http://localhost:4318/v1/logs",
          traces: "http://localhost:4318/v1/traces"
        ),
        debug: true
      ),
      application: ApplicationConfig(applicationVersion: "1.0.0")
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
