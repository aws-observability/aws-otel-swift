
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
    return "6a3cc818-40fa-4266-9561-9ccf2de54567" // rum-mobile-e2e-ios
  }()

  private let region: String = {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("-appMonitorRegion"),
       let index = arguments.firstIndex(of: "-appMonitorRegion"),
       index + 1 < arguments.count {
      return arguments[index + 1]
    }
    return "us-west-2"
  }()

  private let deviceFarmJobId: String = {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("-deviceFarmJobId"),
       let index = arguments.firstIndex(of: "-deviceFarmJobId"),
       index + 1 < arguments.count {
      return arguments[index + 1]
    }
    return "test-device-farm-job-id"
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
    print("Setting up OpenTelemetry with AppMonitorId: \(appMonitorId), Region: \(region)")

    // Set global attributes to filter CW Logs
    let manager = GlobalAttributesProvider.getInstance()
    manager.setAttribute(key: "appMonitorId", value: AttributeValue.string(appMonitorId))
    manager.setAttribute(key: "appMonitorRegion", value: AttributeValue.string(region))
    manager.setAttribute(key: "deviceFarmJobId", value: AttributeValue.string(deviceFarmJobId))

    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let exportOverride = ExportOverride(
      logs: "https://dataplane.rum-gamma.us-west-2.amazonaws.com/v1/rum",
      traces: "https://dataplane.rum-gamma.us-west-2.amazonaws.com/v1/rum"
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
      print("✅ OpenTelemetry SDK initialized successfully")
    } catch AwsOpenTelemetryConfigError.alreadyInitialized {
      print("⚠️ SDK is already initialized")
    } catch {
      print("❌ Error initializing SDK: \(error)")
    }
  }
}
