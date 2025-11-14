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
import OpenTelemetrySdk

/// Span processor that adds battery level to spans
class DeviceKitSpanProcessor: SpanProcessor {
  /// Indicates that this processor needs to be called when spans start
  var isStartRequired = true
  /// Indicates that this processor doesn't need to be called when spans end
  var isEndRequired: Bool = false

  func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    if let batteryLevel = DeviceKitPolyfill.getBatteryLevel() {
      span.setAttribute(key: "hw.battery.charge", value: AttributeValue.double(Double(batteryLevel)))
    }
  }

  func onEnd(span: ReadableSpan) {
    // No action needed
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    // No action needed
  }

  func forceFlush(timeout: TimeInterval?) {
    // No action needed
  }
}
