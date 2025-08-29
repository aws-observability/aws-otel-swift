#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi

  @available(iOS 15.0, *)
  class AwsMetricKitCrashProcessor {
    static let scopeName = "software.amazon.opentelemetry.MXCrashDiagnostic"
    static func processCrashDiagnostics(_ diagnostics: [MXCrashDiagnostic]?) {
      guard let diagnostics else { return }
      let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scopeName)
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) crash diagnostic(s)")

      for crash in diagnostics {
        let attributes = buildCrashAttributes(from: crash)

        AwsOpenTelemetryLogger.debug("Emitting crash log record with \(attributes.count) attributes")
        logger.logRecordBuilder()
          .setBody(AttributeValue.string("crash"))
          .setAttributes(attributes)
          .emit()
      }
    }

    static func buildCrashAttributes(from crash: MXCrashDiagnostic) -> [String: AttributeValue] {
      var attributes: [String: AttributeValue] = [:]

      if let exceptionType = crash.exceptionType {
        attributes["crash.exception_type"] = AttributeValue.int(Int(truncating: exceptionType))
      }

      if let exceptionCode = crash.exceptionCode {
        attributes["crash.exception_code"] = AttributeValue.int(Int(truncating: exceptionCode))
      }

      if let signal = crash.signal {
        attributes["crash.signal"] = AttributeValue.int(Int(truncating: signal))
      }

      if let terminationReason = crash.terminationReason {
        attributes["crash.termination_reason"] = AttributeValue.string(terminationReason)
      }

      if #available(iOS 17.0, *) {
        if let exceptionReason = crash.exceptionReason {
          attributes["crash.exception_reason.type"] = AttributeValue.string(exceptionReason.exceptionType)
          attributes["crash.exception_reason.name"] = AttributeValue.string(exceptionReason.exceptionName)
          attributes["crash.exception_reason.message"] = AttributeValue.string(exceptionReason.composedMessage)
          attributes["crash.exception_reason.class_name"] = AttributeValue.string(exceptionReason.className)
        }
      }

      if let vmRegionInfo = crash.virtualMemoryRegionInfo {
        attributes["crash.vm_region.info"] = AttributeValue.string(vmRegionInfo)
      }

      if let stacktrace = String(bytes: crash.callStackTree.jsonRepresentation(), encoding: .utf8) {
        attributes["crash.stacktrace"] = AttributeValue.string(stacktrace)
      }

      return attributes
    }
  }
#endif
