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

  /// UITests are really slow and flaky, so we will generate telemetries this way for contract tests.
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

          // Trigger app hang. This will also trigger a session start event when the next event is recorded, since we stalled for 5 seconds.
          viewModel.hangApplication(seconds: 5)

          // Trigger warm launch
          await self.mockWarmLaunch()
        }
      }
    }
  }

  private func mockWarmLaunch() async {
    await MainActor.run {
      // Move to background
      NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)

      Task {
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        await MainActor.run {
          // Bring back to foreground
          NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
          NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: UIApplication.shared)
        }
      }
    }
  }
}

class RootViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    let hostingController = UIHostingController(rootView: LoaderView())
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    hostingController.didMove(toParent: self)
  }
}

struct RootViewControllerWrapper: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> RootViewController {
    RootViewController()
  }

  func updateUIViewController(_ uiViewController: RootViewController, context: Context) {}
}

@main
struct SimpleAwsDemoApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      RootViewControllerWrapper()
    }
  }
}
