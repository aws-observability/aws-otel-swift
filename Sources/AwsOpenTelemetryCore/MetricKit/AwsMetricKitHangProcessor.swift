#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi

  @available(iOS 15.0, *)
  class AwsMetricKitHangProcessor {
    static let scopeName = "aws-otel-swift.MXHangDiagnostic"
    static func processHangDiagnostics(_ diagnostics: [MXHangDiagnostic]?) {
      guard let diagnostics else { return }
      let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scopeName)
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) hang diagnostic(s)")

      for hang in diagnostics {
        let attributes = buildHangAttributes(from: hang)

        AwsOpenTelemetryLogger.debug("Emitting hang log record with \(attributes.count) attributes")
        logger.logRecordBuilder()
          .setBody(AttributeValue.string("hang"))
          .setAttributes(attributes)
          .emit()
      }
    }

    static func buildHangAttributes(from hang: MXHangDiagnostic) -> [String: AttributeValue] {
      var attributes: [String: AttributeValue] = [:]

      attributes["hang.hang_duration"] = AttributeValue.double(Double(hang.hangDuration.value.toNanoseconds))

      if let stacktrace = String(bytes: hang.callStackTree.jsonRepresentation(), encoding: .utf8) {
        attributes["hang.call_stack_tree"] = AttributeValue.string(stacktrace)
      }

      return attributes
    }
  }
#endif
