#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi

  @available(iOS 15.0, *)
  class AwsMetricKitHangProcessor {
    static let spanName = "hang"
    static let scopeName = AwsInstrumentationScopes.HANG_DIAGNOSTIC
    static func processHangDiagnostics(_ diagnostics: [MXHangDiagnostic]?, endTime: Date = Date()) {
      guard let diagnostics else { return }
      let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: scopeName)
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) hang diagnostic(s)")

      for hang in diagnostics {
        let attributes = buildHangAttributes(from: hang)

        AwsOpenTelemetryLogger.debug("Emitting hang log record with \(attributes.count) attributes")

        let hangDurationSeconds = Double(hang.hangDuration.converted(to: .seconds).value)
        let startTime = endTime.addingTimeInterval(-hangDurationSeconds)

        let spanBuilder = tracer.spanBuilder(spanName: spanName)
          .setStartTime(time: startTime)

        for (key, value) in attributes {
          spanBuilder.setAttribute(key: key, value: value)
        }

        let span = spanBuilder.startSpan()
        span.end(time: endTime)
      }
    }

    static func buildHangAttributes(from hang: MXHangDiagnostic) -> [String: AttributeValue] {
      var attributes: [String: AttributeValue] = [:]

      attributes[AwsMetricKitConstants.hangDuration] = AttributeValue.double(Double(hang.hangDuration.value.toNanoseconds))

      if let stacktrace = String(bytes: hang.callStackTree.jsonRepresentation(), encoding: .utf8) {
        attributes[AwsMetricKitConstants.hangCallStackTree] = AttributeValue.string(stacktrace)
      }

      return attributes
    }
  }
#endif
