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

/// OpenTelemetry span processor that automatically adds session ID to all spans
/// This processor ensures that all telemetry data is associated with the current session
public class AwsScreenSpanProcessor: SpanProcessor {
  /// Indicates that this processor needs to be called when spans start
  public var isStartRequired = true
  /// Indicates that this processor doesn't need to be called when spans end
  public var isEndRequired: Bool = false
  /// Reference to the session manager for retrieving current session ID
  private var screenManager: AwsScreenManager

  /// Initializes the span processor with a session manager
  /// - Parameter sessionManager: The session manager to use for retrieving session IDs
  public init(screenManager: AwsScreenManager?) {
    AwsInternalLogger.debug("Initializing AwsSessionSpanProcessor")
    self.screenManager = screenManager ?? AwsScreenManagerProvider.getInstance()
  }

  /// Called when a span starts - adds the current session ID as an attribute
  /// - Parameters:
  ///   - parentContext: The parent span context (unused)
  ///   - span: The span being started
  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    if let screenName = screenManager.currentScreen, span.getAttributes()[AwsView.screenName] == nil {
      span.setAttribute(key: AwsView.screenName, value: screenName)
    }
  }

  /// Called when a span ends - no action needed for session tracking
  /// - Parameter span: The span being ended
  public func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
    // No action needed
  }

  /// Shuts down the processor - no cleanup needed
  /// - Parameter explicitTimeout: Timeout for shutdown (unused)
  public func shutdown(explicitTimeout: TimeInterval?) {
    // No cleanup needed
  }

  /// Forces a flush of any pending data - no action needed
  /// - Parameter timeout: Timeout for flush (unused)
  public func forceFlush(timeout: TimeInterval?) {
    // No action needed
  }
}
