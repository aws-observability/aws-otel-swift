import SwiftUI
import AwsOpenTelemetryCore

@main
struct PetClinicApp: App {
  private let appMonitorId = "YOUR_APP_MONITOR_ID_HERE"
  private let region = "YOUR_REGION_HERE"

  init() {
    setupOpenTelemetry()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }

  private func setupOpenTelemetry() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      sessionTimeout: 30,
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
