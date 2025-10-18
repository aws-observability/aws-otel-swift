import SwiftUI
import AwsOpenTelemetryCore

@main
struct PetClinicApp: App {
  private let appMonitorId = "2c20f791-5460-469f-8744-6011ca7e01e5"
  private let region = "us-east-1"

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
    let exportOverride = ExportOverride(
      logs: "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum",
      traces: "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum"
    )
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
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
