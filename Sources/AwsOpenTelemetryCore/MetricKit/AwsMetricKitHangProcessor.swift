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

      for hang in diagnostics {
        let attributes = buildHangAttributes(from: hang)

        logger.logRecordBuilder()
          .setEventName("device.hang")
          .setAttributes(attributes)
          .setTimestamp(Date())
          .emit()
      }
    }

    static func buildHangAttributes(from hang: MXHangDiagnostic) -> [String: AttributeValue] {
      var attributes: [String: AttributeValue] = [:]

      attributes[AwsMetricKitConstants.hangDuration] = AttributeValue.double(Double(hang.hangDuration.value.toNanoseconds))

      if let stacktrace = String(bytes: hang.callStackTree.jsonRepresentation(), encoding: .utf8) {
        attributes[AwsMetricKitConstants.hangCallStack] = AttributeValue.string(stacktrace)
      }

      return attributes
    }
  }
#endif
