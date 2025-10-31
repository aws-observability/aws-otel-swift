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
