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
import UIKit
import AwsOpenTelemetryCore

class AppDelegate: UIResponder, UIApplicationDelegate {
  private var contractTestViewModel: LoaderViewModel?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    if !ProcessInfo.processInfo.arguments.contains("--importCoreNoInitialization") {
      setupOpenTelemetry()
    }
    contractTestHelpers()
    return true
  }

  private func setupOpenTelemetry() {
    let awsConfig = AwsConfig(region: "us-east-1", rumAppMonitorId: "test-app-monitor-id")
    let exportOverride = AwsExportOverride(
      logs: "http://localhost:3000/v1/logs",
      traces: "http://localhost:3000/v1/traces"
    )
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      sessionTimeout: 5,
      otelResourceAttributes: [
        "service.version": "1.0.0",
        "service.name": "SimpleAwsDemo"
      ],
      debug: true
    )
    AwsOpenTelemetryRumBuilder.create(config: config)?.build()
  }

  private func contractTestHelpers() {
    print("Process arguments: \(ProcessInfo.processInfo.arguments)")
    guard ProcessInfo.processInfo.arguments.contains("--contractTestMode") else {
      print("Contract test mode not enabled")
      return
    }

    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)

      await MainActor.run {
        print("Running contractTestHelpers")
        self.contractTestViewModel = LoaderViewModel()

        Task {
          guard let viewModel = self.contractTestViewModel else { return }
          await viewModel.make200Request()
          await viewModel.make4xxRequest()
          await viewModel.make5xxRequest()
          print("Finished making network requests")
        }
      }
    }
  }
}

@main
struct SimpleAwsDemoApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      LoaderView()
    }
  }
}
