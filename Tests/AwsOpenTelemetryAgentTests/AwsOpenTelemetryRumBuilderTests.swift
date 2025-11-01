import XCTest
@testable import AwsOpenTelemetryCore
import OpenTelemetryApi
import OpenTelemetrySdk

final class AwsOpenTelemetryRumBuilderTests: XCTestCase {
  // Define test values
  let region = "us-west-2"
  let appMonitorId = "test-monitor-id"
  let appVersion = "1.0.0"
  let logsEndpoint = "https://logs.example.com"
  let tracesEndpoint = "https://traces.example.com"
  let invalidLogsUrl = "ht tp s://invalid with spaces.com"

  // Reset the shared instance state between tests
  override func tearDown() {
    AwsOpenTelemetryAgent.shared.isInitialized = false
    AwsOpenTelemetryAgent.shared.configuration = nil
    #if canImport(UIKit) && !os(watchOS)
      AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation = nil
    #endif
    super.tearDown()
  }

  func testBasicBuilderCreationAndBuild() {
    // Test basic builder creation and build process
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let applicationAttributes = ["application.version": appVersion]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      applicationAttributes: applicationAttributes
    )

    // Should create builder and build successfully
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config).build())
  }

  func testEndpointConfiguration() {
    // Test both default endpoints and custom overrides
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let exportOverride = ExportOverride(logs: logsEndpoint, traces: tracesEndpoint)
    let applicationAttributes = ["application.version": appVersion]
    let configWithOverrides = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      applicationAttributes: applicationAttributes
    )

    // Should build successfully with endpoint overrides
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: configWithOverrides).build())
  }

  func testInvalidEndpointHandling() {
    // Test handling of invalid endpoint URLs
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let exportOverride = ExportOverride(logs: invalidLogsUrl, traces: nil)
    let applicationAttributes = ["application.version": appVersion]
    let configWithInvalidEndpoint = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      applicationAttributes: applicationAttributes
    )

    // Should throw an error for invalid URL
    XCTAssertThrowsError(try AwsOpenTelemetryRumBuilder.create(config: configWithInvalidEndpoint).build()) { error in
      XCTAssertTrue(error is AwsOpenTelemetryConfigError)
    }
  }

  func testAlreadyInitializedError() {
    // Test that attempting to initialize twice throws an error
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let applicationAttributes = ["application.version": appVersion]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      applicationAttributes: applicationAttributes
    )

    // First initialization should succeed
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config).build())

    // Second initialization should throw error
    XCTAssertThrowsError(try AwsOpenTelemetryRumBuilder.create(config: config).build()) { error in
      XCTAssertTrue(error is AwsOpenTelemetryConfigError)
      if let configError = error as? AwsOpenTelemetryConfigError {
        XCTAssertEqual(configError, AwsOpenTelemetryConfigError.alreadyInitialized)
      }
    }
  }

  func testExporterCustomization() {
    // Test span and log exporter customization
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let applicationAttributes = ["application.version": appVersion]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      applicationAttributes: applicationAttributes
    )

    var spanCustomizerCalled = false
    var logCustomizerCalled = false

    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config)
      .addSpanExporterCustomizer { exporter in
        spanCustomizerCalled = true
        return exporter
      }
      .addLogRecordExporterCustomizer { exporter in
        logCustomizerCalled = true
        return exporter
      }
      .build())

    XCTAssertTrue(spanCustomizerCalled, "Span exporter customizer should be called")
    XCTAssertTrue(logCustomizerCalled, "Log exporter customizer should be called")
  }

  func testProviderCustomization() {
    // Test tracer and logger provider customization
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let applicationAttributes = ["application.version": appVersion]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      applicationAttributes: applicationAttributes
    )

    var tracerCustomizerCalled = false
    var loggerCustomizerCalled = false

    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config)
      .addTracerProviderCustomizer { builder in
        tracerCustomizerCalled = true
        return builder
      }
      .addLoggerProviderCustomizer { builder in
        loggerCustomizerCalled = true
        return builder
      }
      .build())

    XCTAssertTrue(tracerCustomizerCalled, "Tracer provider customizer should be called")
    XCTAssertTrue(loggerCustomizerCalled, "Logger provider customizer should be called")
  }

  func testApplicationAttributesAddedToResource() {
    // Test that applicationAttributes are added to resource during initialization
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let applicationAttributes = [
      "application.version": "1.2.3",
      "application.name": "TestApp"
    ]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      applicationAttributes: applicationAttributes
    )

    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config).build())

    let tracerProvider = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
    let resource = tracerProvider?.resource

    XCTAssertEqual(resource?.attributes["application.version"], AttributeValue.string("1.2.3"))
    XCTAssertEqual(resource?.attributes["application.name"], AttributeValue.string("TestApp"))
  }

  #if canImport(UIKit) && !os(watchOS)
    func testUIKitInstrumentationConfiguration() {
      // Test UIKit instrumentation enabled/disabled/default scenarios

      // Test enabled
      let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
      let applicationAttributes = ["application.version": appVersion]
      let telemetryConfig = TelemetryConfig()
      telemetryConfig.view = TelemetryFeature(enabled: true)
      let enabledConfig = AwsOpenTelemetryConfig(
        aws: awsConfig,
        applicationAttributes: applicationAttributes,
        telemetry: telemetryConfig
      )

      XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: enabledConfig).build())
      XCTAssertNotNil(AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation, "Should create UIKit instrumentation when enabled")

      // Reset for next test
      AwsOpenTelemetryAgent.shared.isInitialized = false
      AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation = nil

      // Test disabled
      let disabledTelemetryConfig = TelemetryConfig()
      disabledTelemetryConfig.view = TelemetryFeature(enabled: false)
      let disabledConfig = AwsOpenTelemetryConfig(
        aws: awsConfig,
        applicationAttributes: applicationAttributes,
        telemetry: disabledTelemetryConfig
      )

      XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: disabledConfig).build())
      XCTAssertNil(AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation, "Should not create UIKit instrumentation when disabled")

      // Reset for next test
      AwsOpenTelemetryAgent.shared.isInitialized = false
      AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation = nil

      // Test default (should be enabled)
      let defaultConfig = AwsOpenTelemetryConfig(
        aws: awsConfig,
        applicationAttributes: applicationAttributes
      )

      XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: defaultConfig).build())
      XCTAssertNotNil(AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation, "Should create UIKit instrumentation by default")
    }
  #endif
}
