#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi

  @available(iOS 15.0, *)
  class AwsMetricKitCrashProcessor {
    static let scopeName = AwsInstrumentationScopes.CRASH_DIAGNOSTIC
    static func processCrashDiagnostics(_ diagnostics: [MXCrashDiagnostic]?) {
      guard let diagnostics else { return }
      let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scopeName)
      AwsOpenTelemetryLogger.debug("Processing \(diagnostics.count) crash diagnostic(s)")

      for crash in diagnostics {
        let attributes = buildCrashAttributes(from: crash)

        AwsOpenTelemetryLogger.debug("Emitting crash log record with \(attributes.count) attributes")
        logger.logRecordBuilder()
          .setEventName(AwsMetricKitConstants.crash)
          .setObservedTimestamp(Date())
          .setAttributes(attributes)
          .emit()
      }
    }

    static func buildCrashAttributes(from crash: MXCrashDiagnostic) -> [String: AttributeValue] {
      var attributes: [String: AttributeValue] = [:]

      if let exceptionType = crash.exceptionType {
        attributes[AwsMetricKitConstants.crashExceptionType] = AttributeValue.int(Int(truncating: exceptionType))
      }

      if let exceptionCode = crash.exceptionCode {
        attributes[AwsMetricKitConstants.crashExceptionCode] = AttributeValue.int(Int(truncating: exceptionCode))
      }

      if let signal = crash.signal {
        attributes[AwsMetricKitConstants.crashSignal] = AttributeValue.int(Int(truncating: signal))
      }

      if let terminationReason = crash.terminationReason {
        attributes[AwsMetricKitConstants.crashTerminationReason] = AttributeValue.string(terminationReason)
      }

      if #available(iOS 17.0, *) {
        if let exceptionReason = crash.exceptionReason {
          attributes[AwsMetricKitConstants.crashExceptionReasonType] = AttributeValue.string(exceptionReason.exceptionType)
          attributes[AwsMetricKitConstants.crashExceptionReasonName] = AttributeValue.string(exceptionReason.exceptionName)
          attributes[AwsMetricKitConstants.crashExceptionReasonMessage] = AttributeValue.string(exceptionReason.composedMessage)
          attributes[AwsMetricKitConstants.crashExceptionReasonClassName] = AttributeValue.string(exceptionReason.className)
        }
      }

      if let vmRegionInfo = crash.virtualMemoryRegionInfo {
        attributes[AwsMetricKitConstants.crashVmRegionInfo] = AttributeValue.string(vmRegionInfo)
      }

      if let stacktrace = String(bytes: crash.callStackTree.jsonRepresentation(), encoding: .utf8) {
        attributes[AwsMetricKitConstants.crashStacktrace] = AttributeValue.string(stacktrace)
      }

      return attributes
    }
  }
#endif
