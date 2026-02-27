
import SwiftUI
import OpenTelemetryApi
import AwsOpenTelemetryCore

@main
struct PetClinicApp: App {
  private let appMonitorId: String = {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("-appMonitorId"),
       let index = arguments.firstIndex(of: "-appMonitorId"),
       index + 1 < arguments.count {
      return arguments[index + 1]
    }
    return "app-monitor-id-uuid" // Replace
  }()

  private let appMonitorRegion: String = {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("-appMonitorRegion"),
       let index = arguments.firstIndex(of: "-appMonitorRegion"),
       index + 1 < arguments.count {
      return arguments[index + 1]
    }
    return "us-west-2" // Replace
  }()

  private let deviceFarmJobId: String = {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("-deviceFarmJobId"),
       let index = arguments.firstIndex(of: "-deviceFarmJobId"),
       index + 1 < arguments.count {
      return arguments[index + 1]
    }
    return "test-device-farm-job-id" // Replace
  }()

  private let environmentSuffix: String = {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("-environmentSuffix"),
       let index = arguments.firstIndex(of: "-environmentSuffix"),
       index + 1 < arguments.count {
      return arguments[index + 1]
    }
    return "" // Replace
  }()

  init() {
    setupOpenTelemetry()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }

  private func setupOpenTelemetry() {
    print("Setting up OpenTelemetry with AppMonitorId: \(appMonitorId), Region: \(appMonitorRegion)")

    // Set global attributes to filter CW Logs
    let manager = AwsGlobalAttributesProvider.getInstance()
    manager.setAttribute(key: "appMonitorId", value: AttributeValue.string(appMonitorId))
    manager.setAttribute(key: "appMonitorRegion", value: AttributeValue.string(appMonitorRegion))
    manager.setAttribute(key: "deviceFarmJobId", value: AttributeValue.string(deviceFarmJobId))

    let awsConfig = AwsConfig(region: appMonitorRegion, rumAppMonitorId: appMonitorId)
    let exportOverride = AwsExportOverride(
      logs: "https://dataplane.rum\\(environmentSuffix).\\(appMonitorRegion).amazonaws.com/v1/rum",
      traces: "https://dataplane.rum\\(environmentSuffix).\\(appMonitorRegion).amazonaws.com/v1/rum"
    )
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      sessionTimeout: 30,
      debug: true
    )

    AwsOpenTelemetryRumBuilder.create(config: config)?.build()
    print("✅ OpenTelemetry SDK initialized successfully")
  }
}
