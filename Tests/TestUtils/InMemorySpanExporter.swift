import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// A simple in-memory span exporter for testing purposes
public class InMemorySpanExporter: SpanExporter {
  private var exportedSpans: [SpanData] = []

  public init() {}

  public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    exportedSpans.append(contentsOf: spans)
    return .success
  }

  public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return .success
  }

  public func shutdown(explicitTimeout: TimeInterval?) {}

  public func getExportedSpans() -> [SpanData] {
    return exportedSpans
  }

  public func reset() {
    exportedSpans.removeAll()
  }

  public static func register() -> InMemorySpanExporter {
    // Create an in-memory span exporter
    let spanExporter = InMemorySpanExporter()

    // Create and register a TracerProvider with the in-memory exporter
    let tracerProvider = TracerProviderBuilder()
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: spanExporter))
      .build()

    // Register the tracer provider with OpenTelemetry
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

    return spanExporter
  }

  public func clear() {
    exportedSpans.removeAll()
  }
}
