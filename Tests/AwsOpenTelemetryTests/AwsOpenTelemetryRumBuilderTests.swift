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
    super.tearDown()
  }

  func testCreateBuilder() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Create the builder
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config))
  }

  func testBuildEndpointURLs() {
    // Create a configuration with region
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Test that build succeeds with valid endpoints
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config).build())
  }

  func testBuildWithEndpointOverrides() {
    // Create a configuration with endpoint overrides
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(
        region: region,
        appMonitorId: appMonitorId,
        overrideEndpoint: EndpointOverrides(
          logs: logsEndpoint,
          traces: tracesEndpoint
        )
      ),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Test that build succeeds with the overrides
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config).build())
  }

  func testBuildWithInvalidEndpoint() {
    // Create a configuration with invalid endpoint override
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(
        region: region,
        appMonitorId: appMonitorId,
        overrideEndpoint: EndpointOverrides(
          logs: invalidLogsUrl,
          traces: tracesEndpoint
        )
      ),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Test that build throws an error for the invalid URL
    XCTAssertThrowsError(try AwsOpenTelemetryRumBuilder.create(config: config).build()) { error in
      XCTAssertTrue(error is AwsOpenTelemetryConfigError)
      if let configError = error as? AwsOpenTelemetryConfigError {
        switch configError {
        case let .malformedURL(url):
          XCTAssertEqual(url, invalidLogsUrl)
        default:
          XCTFail("Expected malformedURL error")
        }
      }
    }
  }

  func testAlreadyInitialized() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // First initialization should succeed
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config).build())

    // Second initialization should throw alreadyInitialized error
    XCTAssertThrowsError(try AwsOpenTelemetryRumBuilder.create(config: config)) { error in
      XCTAssertTrue(error is AwsOpenTelemetryConfigError)
      if let configError = error as? AwsOpenTelemetryConfigError {
        XCTAssertEqual(configError, AwsOpenTelemetryConfigError.alreadyInitialized)
      }
    }
  }

  func testSpanExporterCustomizer() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Create a flag to verify the customizer was called
    var customizerCalled = false

    // Test that customizer is called using chaining
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config)
      .addSpanExporterCustomizer { exporter in
        customizerCalled = true
        return exporter
      }
      .build())

    XCTAssertTrue(customizerCalled, "Span exporter customizer should have been called")
  }

  func testLogRecordExporterCustomizer() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Create a flag to verify the customizer was called
    var customizerCalled = false

    // Test that customizer is called using chaining
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config)
      .addLogRecordExporterCustomizer { exporter in
        customizerCalled = true
        return exporter
      }
      .build())

    XCTAssertTrue(customizerCalled, "Log record exporter customizer should have been called")
  }

  func testMultipleExporterCustomizers() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Create flags to verify the customizers were called
    var firstSpanCustomizerCalled = false
    var secondSpanCustomizerCalled = false
    var logCustomizerCalled = false

    // Test that all customizers are called using chaining
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config)
      .addSpanExporterCustomizer { exporter in
        firstSpanCustomizerCalled = true
        return exporter
      }
      .addSpanExporterCustomizer { exporter in
        secondSpanCustomizerCalled = true
        return exporter
      }
      .addLogRecordExporterCustomizer { exporter in
        logCustomizerCalled = true
        return exporter
      }
      .build())

    XCTAssertTrue(firstSpanCustomizerCalled, "First span exporter customizer should have been called")
    XCTAssertTrue(secondSpanCustomizerCalled, "Second span exporter customizer should have been called")
    XCTAssertTrue(logCustomizerCalled, "Log record exporter customizer should have been called")
  }

  func testTracerProviderCustomizer() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Create a flag to verify the customizer was called
    var customizerCalled = false

    // Test that customizer is called using chaining
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config)
      .addTracerProviderCustomizer { builder in
        customizerCalled = true
        return builder
      }
      .build())

    XCTAssertTrue(customizerCalled, "Tracer provider customizer should have been called")
  }

  func testLoggerProviderCustomizer() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Create a flag to verify the customizer was called
    var customizerCalled = false

    // Test that customizer is called using chaining
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config)
      .addLoggerProviderCustomizer { builder in
        customizerCalled = true
        return builder
      }
      .build())

    XCTAssertTrue(customizerCalled, "Logger provider customizer should have been called")
  }

  func testMultipleProviderCustomizers() {
    // Create a valid configuration
    let config = AwsOpenTelemetryConfig(
      rum: RumConfig(region: region, appMonitorId: appMonitorId),
      application: ApplicationConfig(applicationVersion: appVersion)
    )

    // Create flags to verify the customizers were called
    var firstTracerCustomizerCalled = false
    var secondTracerCustomizerCalled = false
    var loggerCustomizerCalled = false

    // Test that all customizers are called using chaining
    XCTAssertNoThrow(try AwsOpenTelemetryRumBuilder.create(config: config)
      .addTracerProviderCustomizer { builder in
        firstTracerCustomizerCalled = true
        return builder
      }
      .addTracerProviderCustomizer { builder in
        secondTracerCustomizerCalled = true
        return builder
      }
      .addLoggerProviderCustomizer { builder in
        loggerCustomizerCalled = true
        return builder
      }
      .build())

    XCTAssertTrue(firstTracerCustomizerCalled, "First tracer provider customizer should have been called")
    XCTAssertTrue(secondTracerCustomizerCalled, "Second tracer provider customizer should have been called")
    XCTAssertTrue(loggerCustomizerCalled, "Logger provider customizer should have been called")
  }
}
