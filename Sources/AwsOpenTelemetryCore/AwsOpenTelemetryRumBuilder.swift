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

#if canImport(UIKit) && !os(watchOS)
  import UIKit
#endif

/**
 * Builder for configuring and initializing the AWS OpenTelemetry SDK with RUM capabilities.
 *
 * This class provides a fluent API for setting up the complete OpenTelemetry pipeline
 * optimized for AWS Real User Monitoring (RUM). It handles the configuration of:
 *
 * - **Tracer Provider**: For creating and managing distributed traces
 * - **Logger Provider**: For structured logging with OpenTelemetry context
 * - **Exporters**: For sending telemetry data to AWS CloudWatch RUM
 * - **Resources**: For identifying the application and runtime environment
 * - **Instrumentation**: For configuring and creating instrumentation modules
 *
 * This builder is not thread-safe and should be used from a single thread.
 * However, the resulting OpenTelemetry components are thread-safe once built.
 */
public class AwsOpenTelemetryRumBuilder {
  private var tracerProviderCustomizers: [(TracerProviderBuilder) -> TracerProviderBuilder] = []
  private var loggerProviderCustomizers: [(LoggerProviderBuilder) -> LoggerProviderBuilder] = []

  private var config: AwsOpenTelemetryConfig

  private var spanExporterCustomizer: (SpanExporter) -> SpanExporter = { $0 }
  private var logRecordExporterCustomizer: (LogRecordExporter) -> LogRecordExporter = { $0 }

  private var resource: Resource

  #if canImport(UIKit) && !os(watchOS)
    private var uiKitViewInstrumentation: UIKitViewInstrumentation?
  #endif

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
      AwsOpenTelemetryLogger.debug("SDK is already initialized.")
      throw AwsOpenTelemetryConfigError.alreadyInitialized
    }

    // Store the configuration in the shared instance
    AwsOpenTelemetryAgent.shared.configuration = config
    AwsOpenTelemetryLogger.info("Creating builder with region: \(config.aws.region), appMonitorId: \(config.aws.rumAppMonitorId)")

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
    // Configure session manager with timeout from config
    let sessionConfig = AwsSessionConfig(sessionTimeout: config.sessionTimeout ?? AwsSessionConfig.default.sessionTimeout)
    let sessionManager = AwsSessionManager(configuration: sessionConfig)
    AwsSessionManagerProvider.register(sessionManager: sessionManager)
  }

  /**
   * Builds and initializes the complete AWS OpenTelemetry SDK pipeline.
   *
   * This method performs the following operations:
   * 1. Validates and constructs endpoint URLs for traces and logs
   * 2. Creates and configures span and log record exporters
   * 3. Applies any registered exporter customizations
   * 4. Builds tracer and logger providers with customizations
   * 5. Registers providers with the global OpenTelemetry instance
   * 6. Initializes UIKit instrumentation (if enabled and available)
   * 7. Marks the SDK as initialized to prevent duplicate initialization
   *
   * ## Error Handling
   *
   * This method will throw an error if:
   * - Endpoint URLs are malformed or invalid
   * - Required configuration parameters are missing
   * - The SDK has already been initialized
   *
   * ## Thread Safety
   *
   * This method is not thread-safe and should only be called once during
   * application initialization, typically from the main thread.
   *
   * @throws AwsOpenTelemetryConfigError.malformedURL if endpoint URLs are invalid
   * @return This builder instance for method chaining
   */
  @discardableResult
  public func build() throws -> Self {
    // AWS OpenTelemetry Swift SDK instrumentation constants

    let tracesEndpoint = buildTracesEndpoint(region: config.aws.region, exportOverride: config.exportOverride)
    guard let tracesEndpointURL = URL(string: tracesEndpoint) else {
      throw AwsOpenTelemetryConfigError.malformedURL(tracesEndpoint)
    }
    let logsEndpoint = buildLogsEndpoint(region: config.aws.region, exportOverride: config.exportOverride)
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
    AwsOpenTelemetryLogger.info("AwsOpenTelemetry initialized successfully")

    buildInstrumentations()

    return self
  }

  var instrumentationPlan: InstrumentationPlan {
    guard let telemetry = config.telemetry else {
      return InstrumentationPlan()
    }

    return InstrumentationPlan(
      sessionEvents: telemetry.sessionEvents?.enabled == true,
      view: telemetry.view?.enabled == true,
      crash: telemetry.crash?.enabled == true,
      network: telemetry.network?.enabled == true
    )
  }

  /**
   * Builds and applies all instrumentations after OpenTelemetry is initialized.
   */
  private func buildInstrumentations() {
    let plan = instrumentationPlan

    // Session Events
    if plan.sessionEvents {
      _ = AwsSessionEventInstrumentation()
    }

    // View instrumentation (UIKit/SwiftUI)
    #if canImport(UIKit) && !os(watchOS)
      if plan.view {
        uiKitViewInstrumentation = UIKitViewInstrumentation(tracer: OpenTelemetry.instance.tracerProvider.get(instrumentationName: "software.amazon.opentelemetry.UIKitView"))
        uiKitViewInstrumentation!.install()
        AwsOpenTelemetryAgent.shared.uiKitViewInstrumentation = uiKitViewInstrumentation
      }
    #endif

    // MetricKit (crashes)
    #if canImport(MetricKit) && !os(tvOS) && !os(macOS)
      if plan.crash {
        if #available(iOS 15.0, *) {
          let metricKitSubscriber = AwsMetricKitSubscriber()
          metricKitSubscriber.subscribe()
          AwsOpenTelemetryAgent.shared.metricKitSubscriber = metricKitSubscriber
        }
      }
    #endif

    // Network (URLSession)
    if plan.network {
      let urlSessionConfig = AwsURLSessionConfig(region: config.aws.region, exportOverride: config.exportOverride)
      let urlSessionInstrumentation = AwsURLSessionInstrumentation(config: urlSessionConfig)
      urlSessionInstrumentation.apply()
    }
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
   * This allows you to wrap or replace the default span exporter with custom logic.
   * Common use cases include:
   * - Adding multiple exporters using `MultiSpanExporter`
   * - Filtering spans before export
   * - Adding custom headers or authentication
   * - Implementing custom retry logic
   *
   * Multiple customizers can be chained and will be applied in the order they were added.
   *
   * @param customizer A function that takes the current span exporter and returns a modified version
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
   * This allows you to wrap or replace the default log record exporter with custom logic.
   * Common use cases include:
   * - Adding multiple exporters for logs
   * - Filtering log records before export
   * - Adding custom formatting or enrichment
   * - Implementing custom batching strategies
   *
   * Multiple customizers can be chained and will be applied in the order they were added.
   *
   * @param customizer A function that takes the current log record exporter and returns a modified version
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
   * This allows you to customize the tracer provider configuration before it's built.
   * Common use cases include:
   * - Adding custom span processors for filtering or enrichment
   * - Configuring sampling strategies
   * - Adding custom resource attributes
   * - Setting up span limits and timeouts
   *
   * Multiple customizers can be added and will be applied in the order they were added.
   *
   * @param customizer A function that takes the tracer provider builder and returns a modified version
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
   * This allows you to customize the logger provider configuration before it's built.
   * Common use cases include:
   * - Adding custom log record processors
   * - Configuring log level filtering
   * - Setting up custom resource attributes for logs
   * - Implementing custom log record enrichment
   *
   * Multiple customizers can be added and will be applied in the order they were added.
   *
   * @param customizer A function that takes the logger provider builder and returns a modified version
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
      AwsRumConstants.AWS_REGION: config.aws.region,
      AwsRumConstants.RUM_APP_MONITOR_ID: config.aws.rumAppMonitorId,
      AwsRumConstants.RUM_SDK_VERSION: AwsOpenTelemetryAgent.version
    ]

    if config.aws.rumAlias?.isEmpty == false {
      rumResourceAttributes[AwsRumConstants.RUM_ALIAS] = config.aws.rumAlias!
    }

    let resource = DefaultResources().get()
      .merging(other: Resource(attributes: buildAttributeMap(rumResourceAttributes)))

    return resource
  }

  /**
   * Builds the span exporter.
   *
   * @param tracesEndpointURL The traces endpoint URL
   * @return A configured span exporter
   */
  private func buildSpanExporter(tracesEndpointURL: URL) -> SpanExporter {
    let traceExporter = OtlpHttpTraceExporter(endpoint: tracesEndpointURL)
    let defaultExporter: SpanExporter = if config.debug ?? false {
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
    let defaultExporter: LogRecordExporter = if config.debug ?? false {
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
      .add(spanProcessor: AwsSessionSpanProcessor(sessionManager: AwsSessionManagerProvider.getInstance()))
      .add(spanProcessor: AwsUIDSpanProcessor())
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
      .with(processors: [BatchLogRecordProcessor(logRecordExporter: logExporter)])
      .with(resource: resource)

    // Apply all customizers in order
    let customizedBuilder = loggerProviderCustomizers.reduce(builder) { builder, customizer in
      customizer(builder)
    }

    // Build final provider
    return customizedBuilder.build()
  }
}

struct InstrumentationPlan {
  let sessionEvents: Bool
  let view: Bool
  let crash: Bool
  let network: Bool

  init(sessionEvents: Bool = false, view: Bool = false, crash: Bool = false, network: Bool = false) {
    self.sessionEvents = sessionEvents
    self.view = view
    self.crash = crash
    self.network = network
  }
}
