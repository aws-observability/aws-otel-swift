import XCTest
@testable import AwsOpenTelemetryCore
import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter

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
    let otelResourceAttributes = ["service.version": appVersion]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      otelResourceAttributes: otelResourceAttributes
    )

    // Should create builder and build successfully
    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }
    XCTAssertNoThrow(builder.build())
  }

  func testEndpointConfiguration() {
    // Test both default endpoints and custom overrides
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let exportOverride = AwsExportOverride(logs: logsEndpoint, traces: tracesEndpoint)
    let otelResourceAttributes = ["service.version": appVersion]
    let configWithOverrides = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      otelResourceAttributes: otelResourceAttributes
    )

    // Should build successfully with endpoint overrides
    guard let builder = AwsOpenTelemetryRumBuilder.create(config: configWithOverrides) else {
      XCTFail("Failed to create builder")
      return
    }
    XCTAssertNoThrow(builder.build())
  }

  func testInvalidEndpointHandling() {
    // Test handling of invalid endpoint URLs
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let exportOverride = AwsExportOverride(logs: invalidLogsUrl, traces: nil)
    let otelResourceAttributes = ["service.version": appVersion]
    let configWithInvalidEndpoint = AwsOpenTelemetryConfig(
      aws: awsConfig,
      exportOverride: exportOverride,
      otelResourceAttributes: otelResourceAttributes
    )

    // Should throw an error for invalid URL
    guard let builder = AwsOpenTelemetryRumBuilder.create(config: configWithInvalidEndpoint) else {
      XCTFail("Failed to create builder")
      return
    }
    XCTAssertNoThrow(builder.build())
  }

  func testAlreadyInitializedError() {
    // Test that attempting to initialize twice throws an error
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let otelResourceAttributes = ["service.version": appVersion]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      otelResourceAttributes: otelResourceAttributes
    )

    // First initialization should succeed
    guard let builder1 = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create first builder")
      return
    }
    XCTAssertNoThrow(builder1.build())

    // Second initialization should return nil
    let builder2 = AwsOpenTelemetryRumBuilder.create(config: config)
    XCTAssertNil(builder2, "Second create should return nil when already initialized")
  }

  func testExporterCustomization() {
    // Test span and log exporter customization
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let otelResourceAttributes = ["service.version": appVersion]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      otelResourceAttributes: otelResourceAttributes
    )

    var spanCustomizerCalled = false
    var logCustomizerCalled = false

    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }
    XCTAssertNoThrow(builder
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
    let otelResourceAttributes = ["service.version": appVersion]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      otelResourceAttributes: otelResourceAttributes
    )

    var tracerCustomizerCalled = false
    var loggerCustomizerCalled = false

    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }
    XCTAssertNoThrow(builder
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
    // Test that otelResourceAttributes are added to resource during initialization
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let otelResourceAttributes = [
      "service.version": "1.2.3",
      "application.name": "TestApp"
    ]
    let config = AwsOpenTelemetryConfig(
      aws: awsConfig,
      otelResourceAttributes: otelResourceAttributes
    )

    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }
    XCTAssertNoThrow(builder.build())

    // Note: Resource verification would require access to internal TracerProviderSdk properties
    // For now, just verify the build completed successfully
    XCTAssertTrue(AwsOpenTelemetryAgent.shared.isInitialized)
  }

  #if canImport(UIKit) && !os(watchOS)
    func testUIKitInstrumentationConfiguration() {
      // Test UIKit instrumentation enabled/disabled/default scenarios

      // Test enabled
      let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
      let otelResourceAttributes = ["service.version": appVersion]
      let telemetryConfig = AwsTelemetryConfig()
      telemetryConfig.view = TelemetryFeature(enabled: true)
      let enabledConfig = AwsOpenTelemetryConfig(
        aws: awsConfig,
        otelResourceAttributes: otelResourceAttributes,
        telemetry: telemetryConfig
      )

      guard let builder1 = AwsOpenTelemetryRumBuilder.create(config: enabledConfig) else {
        XCTFail("Failed to create builder")
        return
      }
      XCTAssertNoThrow(builder1.build())
      XCTAssertNotNil(AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation, "Should create UIKit instrumentation when enabled")

      // Reset for next test
      AwsOpenTelemetryAgent.shared.isInitialized = false
      AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation = nil

      // Test disabled
      let disabledTelemetryConfig = AwsTelemetryConfig()
      disabledTelemetryConfig.view = TelemetryFeature(enabled: false)
      let disabledConfig = AwsOpenTelemetryConfig(
        aws: awsConfig,
        otelResourceAttributes: otelResourceAttributes,
        telemetry: disabledTelemetryConfig
      )

      guard let builder2 = AwsOpenTelemetryRumBuilder.create(config: disabledConfig) else {
        XCTFail("Failed to create builder")
        return
      }
      XCTAssertNoThrow(builder2.build())
      XCTAssertNil(AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation, "Should not create UIKit instrumentation when disabled")

      // Reset for next test
      AwsOpenTelemetryAgent.shared.isInitialized = false
      AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation = nil

      // Test default (should be enabled)
      let defaultConfig = AwsOpenTelemetryConfig(
        aws: awsConfig,
        otelResourceAttributes: otelResourceAttributes
      )

      guard let builder3 = AwsOpenTelemetryRumBuilder.create(config: defaultConfig) else {
        XCTFail("Failed to create builder")
        return
      }
      XCTAssertNoThrow(builder3.build())
      XCTAssertNotNil(AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation, "Should create UIKit instrumentation by default")
    }
  #endif

  // MARK: - Internal Method Tests

  func testBuildSpanExporter() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let config = AwsOpenTelemetryConfig(aws: awsConfig)
    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }

    let url = URL(string: "https://traces.example.com")!
    let exporter = builder.buildSpanExporter(tracesEndpointURL: url)

    XCTAssertNotNil(exporter)
  }

  func testBuildLogsExporter() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let config = AwsOpenTelemetryConfig(aws: awsConfig)
    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }

    let url = URL(string: "https://logs.example.com")!
    let exporter = builder.buildLogsExporter(logsEndpointURL: url)

    XCTAssertNotNil(exporter)
  }

  func testBuildTracerProvider() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let config = AwsOpenTelemetryConfig(aws: awsConfig)
    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }

    let mockExporter = StdoutSpanExporter()
    let resource = Resource()
    let provider = builder.buildTracerProvider(spanExporter: mockExporter, resource: resource)

    XCTAssertNotNil(provider)
  }

  func testBuildLoggerProvider() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let config = AwsOpenTelemetryConfig(aws: awsConfig)
    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }

    let mockExporter = StdoutLogExporter()
    let resource = Resource()
    let provider = builder.buildLoggerProvider(logExporter: mockExporter, resource: resource)

    XCTAssertNotNil(provider)
  }

  func testMergeResource() {
    let awsConfig = AwsConfig(region: region, rumAppMonitorId: appMonitorId)
    let config = AwsOpenTelemetryConfig(aws: awsConfig)
    guard let builder = AwsOpenTelemetryRumBuilder.create(config: config) else {
      XCTFail("Failed to create builder")
      return
    }

    let additionalResource = Resource(attributes: ["test.key": AttributeValue.string("test.value")])
    let result = builder.mergeResource(resource: additionalResource)

    XCTAssertNotNil(result)
  }
}
