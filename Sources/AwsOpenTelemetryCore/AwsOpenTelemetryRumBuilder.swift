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

import Foundation

import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import ResourceExtension
import StdoutExporter

/**
 * Main entry point for the AWS OpenTelemetry SDK.
 * Builder for AWS OpenTelemetry RUM (Real User Monitoring) implementation.
 *
 * This class provides a fluent API for configuring and building the OpenTelemetry
 * components needed for AWS RUM, including tracer and logger providers, exporters,
 * and resources.
 */
public class AwsOpenTelemetryRumBuilder {
  private var tracerProviderCustomizers: [(TracerProviderBuilder) -> TracerProviderBuilder] = []
  private var loggerProviderCustomizers: [(LoggerProviderBuilder) -> LoggerProviderBuilder] = []

  private var config: AwsOpenTelemetryConfig

  private var spanExporterCustomizer: (SpanExporter) -> SpanExporter = { $0 }
  private var logRecordExporterCustomizer: (LogRecordExporter) -> LogRecordExporter = { $0 }

  private var resource: Resource

  // Track instrumentations to add
  private var instrumentations: [AwsOpenTelemetryInstrumentationProtocol] = []

  // MARK: - Initialization Methods

  /**
   * Creates a new builder instance with the specified configuration.
   * This method checks if the SDK is already initialized to ensure thread safety.
   *
   * @param config The AWS OpenTelemetry configuration
   * @return A new builder instance
   * @throws AwsOpenTelemetryConfigError.alreadyInitialized if the SDK is already initialized
   */
  public static func create(config: AwsOpenTelemetryConfig) throws -> AwsOpenTelemetryRumBuilder {
    // Check if the SDK is already initialized
    guard !AwsOpenTelemetryAgent.shared.isInitialized else {
      print("[AwsOpenTelemetry] SDK is already initialized.")
      throw AwsOpenTelemetryConfigError.alreadyInitialized
    }

    // Store the configuration in the shared instance
    AwsOpenTelemetryAgent.shared.configuration = config
    print("[AwsOpenTelemetry] Creating builder with region: \(config.rum.region), appMonitorId: \(config.rum.appMonitorId)")

    return AwsOpenTelemetryRumBuilder(config: config)
  }

  /**
   * Private initializer for the builder.
   *
   * @param config The AWS OpenTelemetry configuration
   */
  private init(config: AwsOpenTelemetryConfig) {
    self.config = config
    resource = Self.buildResource(config: config)
  }

  // MARK: - Instrumentation Methods

  /**
   * Adds an instrumentation instance to the RUM configuration.
   * The instrumentation will be applied when build() is called.
   *
   * @param instrumentation The instrumentation instance to add
   * @return This builder instance for method chaining
   */
  @discardableResult
  public func addInstrumentation<T: AwsOpenTelemetryInstrumentationProtocol>(_ instrumentation: T) -> Self {
    instrumentations.append(instrumentation)
    return self
  }

  /**
   * Builds and registers the OpenTelemetry components.
   * This method marks the SDK as initialized when successful.
   *
   * @throws AwsOpenTelemetryConfigError if endpoint URLs are malformed
   * @return Self for method chaining
   */
  @discardableResult
  public func build() throws -> Self {
    let tracesEndpoint = buildTracesEndpoint(config: config.rum)
    guard let tracesEndpointURL = URL(string: tracesEndpoint) else {
      throw AwsOpenTelemetryConfigError.malformedURL(tracesEndpoint)
    }
    let logsEndpoint = buildLogsEndpoint(config: config.rum)
    guard let logsEndpointURL = URL(string: logsEndpoint) else {
      throw AwsOpenTelemetryConfigError.malformedURL(logsEndpoint)
    }

    let spanExporter = buildSpanExporter(tracesEndpointURL: tracesEndpointURL)
    let logsExporter = buildLogsExporter(logsEndpointURL: logsEndpointURL)

    let tracerProvider = buildTracerProvider(spanExporter: spanExporter, resource: resource)
    let loggerProvider = buildLoggerProvider(logExporter: logsExporter, resource: resource)

    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

    // Mark the SDK as initialized
    AwsOpenTelemetryAgent.shared.isInitialized = true
    print("[AwsOpenTelemetry] AwsOpenTelemetry initialized successfully")

    // Apply all stored instrumentations after OpenTelemetry is fully initialized
    applyInstrumentations()

    return self
  }

  /**
   * Applies all stored instrumentations after OpenTelemetry is initialized.
   */
  private func applyInstrumentations() {
    print("[AwsOpenTelemetry] Applying \(instrumentations.count) instrumentations")

    for instrumentation in instrumentations {
      instrumentation.apply()
    }

    print("[AwsOpenTelemetry] All instrumentations applied successfully")
  }

  // MARK: - Resource methods

  /**
   * Merges additional resource attributes with the existing resource.
   *
   * @param resource The resource to merge with the existing resource
   * @return This builder instance for method chaining
   */
  public func mergeResource(resource: Resource) -> Self {
    self.resource = self.resource.merging(other: resource)
    return self
  }

  // MARK: - Exporter Customizer Methods

  /**
   * Adds a customizer for the span exporter.
   *
   * @param customizer A function that transforms a span exporter
   * @return This builder instance for method chaining
   */
  @discardableResult
  public func addSpanExporterCustomizer(
    _ customizer: @escaping (SpanExporter) -> SpanExporter
  ) -> Self {
    let existing = spanExporterCustomizer
    spanExporterCustomizer = { exporter in
      let intermediate = existing(exporter)
      return customizer(intermediate)
    }
    return self
  }

  /**
   * Adds a customizer for the log record exporter.
   *
   * @param customizer A function that transforms a log record exporter
   * @return This builder instance for method chaining
   */
  @discardableResult
  public func addLogRecordExporterCustomizer(
    _ customizer: @escaping (LogRecordExporter) -> LogRecordExporter
  ) -> Self {
    let existing = logRecordExporterCustomizer
    logRecordExporterCustomizer = { exporter in
      let intermediate = existing(exporter)
      return customizer(intermediate)
    }
    return self
  }

  // MARK: - Provider Customizer Methods

  /**
   * Adds a customizer for the tracer provider builder.
   *
   * @param customizer A function that transforms a tracer provider builder
   * @return This builder instance for method chaining
   */
  @discardableResult
  public func addTracerProviderCustomizer(
    _ customizer: @escaping (TracerProviderBuilder) -> TracerProviderBuilder
  ) -> Self {
    tracerProviderCustomizers.append(customizer)
    return self
  }

  /**
   * Adds a customizer for the logger provider builder.
   *
   * @param customizer A function that transforms a logger provider builder
   * @return This builder instance for method chaining
   */
  @discardableResult
  public func addLoggerProviderCustomizer(
    _ customizer: @escaping (LoggerProviderBuilder) -> LoggerProviderBuilder
  ) -> Self {
    loggerProviderCustomizers.append(customizer)
    return self
  }

  // MARK: - Builder methods

  /**
   * Converts a string-to-string map to an attribute map.
   *
   * @param map The string-to-string map to convert
   * @return A map of attribute values
   */
  private static func buildAttributeMap(_ map: [String: String]) -> [String: AttributeValue] {
    var attributeMap: [String: AttributeValue] = [:]
    for (key, value) in map {
      attributeMap[key] = AttributeValue(value)
    }
    return attributeMap
  }

  /**
   * Builds the resource with AWS RUM attributes.
   *
   * @param config The AWS OpenTelemetry configuration
   * @return A resource with AWS RUM attributes
   */
  private static func buildResource(config: AwsOpenTelemetryConfig) -> Resource {
    var rumResourceAttributes: [String: String] = [
      AwsRumConstants.AWS_REGION: config.rum.region,
      AwsRumConstants.RUM_APP_MONITOR_ID: config.rum.appMonitorId
    ]

    if config.rum.alias?.isEmpty == false {
      rumResourceAttributes[AwsRumConstants.RUM_ALIAS] = config.rum.alias!
    }

    let resource = DefaultResources().get()
      .merging(other: Resource(attributes: buildAttributeMap(rumResourceAttributes)))

    return resource
  }

  /**
   * Builds the base RUM endpoint URL for a given region.
   *
   * @param region The AWS region
   * @return The base RUM endpoint URL
   */
  private func buildRumEndpoint(region: String) -> String {
    return "https://dataplane.rum.\(region).amazonaws.com/v1/rum"
  }

  /**
   * Builds the traces endpoint URL.
   *
   * @param config The RUM configuration
   * @return The traces endpoint URL
   */
  private func buildTracesEndpoint(config: RumConfig) -> String {
    return config.overrideEndpoint?.traces ?? buildRumEndpoint(region: config.region)
  }

  /**
   * Builds the logs endpoint URL.
   *
   * @param config The RUM configuration
   * @return The logs endpoint URL
   */
  private func buildLogsEndpoint(config: RumConfig) -> String {
    return config.overrideEndpoint?.logs ?? buildRumEndpoint(region: config.region)
  }

  /**
   * Builds the span exporter.
   *
   * @param tracesEndpointURL The traces endpoint URL
   * @return A configured span exporter
   */
  private func buildSpanExporter(tracesEndpointURL: URL) -> SpanExporter {
    let traceExporter = OtlpHttpTraceExporter(endpoint: tracesEndpointURL)
    let defaultExporter: SpanExporter = if config.rum.debug ?? false {
      MultiSpanExporter(spanExporters: [
        traceExporter,
        StdoutSpanExporter()
      ])
    } else {
      traceExporter
    }

    return spanExporterCustomizer(defaultExporter)
  }

  /**
   * Builds the log record exporter.
   *
   * @param logsEndpointURL The logs endpoint URL
   * @return A configured log record exporter
   */
  private func buildLogsExporter(logsEndpointURL: URL) -> LogRecordExporter {
    let logsExporter = OtlpHttpLogExporter(endpoint: logsEndpointURL)
    let defaultExporter: LogRecordExporter = if config.rum.debug ?? false {
      MultiLogRecordExporter(logRecordExporters: [
        logsExporter,
        StdoutLogExporter()
      ]) // TODO: Replace with upstream's once it's made public
    } else {
      logsExporter
    }

    return logRecordExporterCustomizer(defaultExporter)
  }

  /**
   * Builds the tracer provider.
   *
   * @param spanExporter The span exporter to use
   * @param resource The resource to associate with the tracer provider
   * @return A configured tracer provider
   */
  private func buildTracerProvider(spanExporter: SpanExporter,
                                   resource: Resource) -> TracerProvider {
    // Create initial builder
    let builder = TracerProviderBuilder()
      .add(spanProcessor: MultiSpanProcessor(
        spanProcessors: [BatchSpanProcessor(spanExporter: spanExporter)]
      ))
      .with(resource: resource)

    // Apply all customizers in order
    let customizedBuilder = tracerProviderCustomizers.reduce(builder) { builder, customizer in
      customizer(builder)
    }

    // Build final provider
    return customizedBuilder.build()
  }

  /**
   * Builds the logger provider.
   *
   * @param logExporter The log record exporter to use
   * @param resource The resource to associate with the logger provider
   * @return A configured logger provider
   */
  private func buildLoggerProvider(logExporter: LogRecordExporter,
                                   resource: Resource) -> LoggerProvider {
    // Create initial builder
    let builder = LoggerProviderBuilder()
      .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
      .with(resource: resource)

    // Apply all customizers in order
    let customizedBuilder = loggerProviderCustomizers.reduce(builder) { builder, customizer in
      customizer(builder)
    }

    // Build final provider
    return customizedBuilder.build()
  }
}
