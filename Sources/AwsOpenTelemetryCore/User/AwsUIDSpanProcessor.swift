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
import OpenTelemetrySdk
import OpenTelemetryApi

/// OpenTelemetry span processor that automatically adds UID to all spans
/// This processor ensures that all telemetry data is associated with a unique user identifier
class AwsUIDSpanProcessor: SpanProcessor {
  /// Indicates that this processor needs to be called when spans start
  var isStartRequired = true
  /// Indicates that this processor doesn't need to be called when spans end
  var isEndRequired: Bool = false
  /// The attribute key used to store UID in spans
  var userIdKey = AwsUserSemvConv.id
  /// Reference to the UID manager for retrieving current UID
  private var uidManager: AwsUIDManager

  /// Initializes the span processor with a UID manager
  /// - Parameter uidManager: The UID manager to use for retrieving UID
  init(uidManager: AwsUIDManager) {
    self.uidManager = uidManager
  }

  /// Called when a span starts - adds the current UID as an attribute
  /// - Parameters:
  ///   - parentContext: The parent span context (unused)
  ///   - span: The span being started
  func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    let uid = uidManager.getUID()
    span.setAttribute(key: userIdKey, value: uid)
  }

  /// Called when a span ends - no action needed for UID tracking
  /// - Parameter span: The span being ended
  func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
    // No action needed
  }

  /// Shuts down the processor - no cleanup needed
  /// - Parameter explicitTimeout: Timeout for shutdown (unused)
  func shutdown(explicitTimeout: TimeInterval?) {
    // No cleanup needed
  }

  /// Forces a flush of any pending data - no action needed
  /// - Parameter timeout: Timeout for flush (unused)
  func forceFlush(timeout: TimeInterval?) {
    // No action needed
  }
}
