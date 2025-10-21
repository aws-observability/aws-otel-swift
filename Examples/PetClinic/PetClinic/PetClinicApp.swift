import SwiftUI
import AwsOpenTelemetryCore

@main
struct PetClinicApp: App {
  init() {
    setupOpenTelemetry()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }

  private func setupOpenTelemetry() {
    var APP_MONITOR_ID = "APP_MONITOR_ID"
    var AWS_REGION = "AWS_REGION"
    var LOGS_OVERRIDE_URL = "LOGS_OVERRIDE_URL"
    var TRACES_OVERRIDE_URL = "TRACES_OVERRIDE_URL"

    if let path = Bundle.main.path(forResource: "Settings", ofType: "plist"),
       let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
      if let appMonitorId = dict["APP_MONITOR_ID"] as? String {
        APP_MONITOR_ID = appMonitorId
        print("APP_MONITOR_ID: \(appMonitorId)")
      }
      if let region = dict["AWS_REGION"] as? String {
        AWS_REGION = region
        print("AWS_REGION: \(region)")
      }
      if let logsOverrideUrl = dict["LOGS_OVERRIDE_URL"] as? String {
        LOGS_OVERRIDE_URL = logsOverrideUrl
        print("LOGS_OVERRIDE_URL: \(logsOverrideUrl)")
      }
      if let tracesOverrideUrl = dict["TRACES_OVERRIDE_URL"] as? String {
        TRACES_OVERRIDE_URL = tracesOverrideUrl
        print("TRACES_OVERRIDE_URL: \(tracesOverrideUrl)")
      }
    } else {
      print("Error: Settings.plist not found or could not be read.")
    }

    let awsConfig = AwsConfig(region: AWS_REGION, rumAppMonitorId: APP_MONITOR_ID)
    let exportOverride = ExportOverride(
      logs: LOGS_OVERRIDE_URL,
      traces: TRACES_OVERRIDE_URL
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
