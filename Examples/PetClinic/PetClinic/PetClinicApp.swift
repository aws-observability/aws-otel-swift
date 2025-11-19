import SwiftUI
import AwsOpenTelemetryCore

@main
struct PetClinicApp: App {
  private let appMonitorId = "654e73e4-0b59-4ba0-943a-a5ebab5ecf37"
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
    let exportOverride = AwsExportOverride(
      logs: "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum",
      traces: "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum"
    )
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      sessionTimeout: 30,
//      applicationAttributes: ["service.version" : "1.0.0"],
      debug: true
//      xForwardedFor: "99.49.114.104" // San Jose, California, USA*/
    )
    AwsOpenTelemetryRumBuilder.create(config: config)?.build()
  }
}
