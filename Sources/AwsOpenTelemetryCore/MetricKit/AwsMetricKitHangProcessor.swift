#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi

  @available(iOS 15.0, *)
  class AwsMetricKitHangProcessor {
    static let scopeName = AwsInstrumentationScopes.HANG_DIAGNOSTIC
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
          .setObservedTimestamp(Date())
          .emit()
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
