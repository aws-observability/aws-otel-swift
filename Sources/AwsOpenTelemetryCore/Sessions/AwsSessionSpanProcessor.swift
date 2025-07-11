import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

/// OpenTelemetry span processor that automatically adds session ID to all spans
/// This processor ensures that all telemetry data is associated with the current session
class AwsSessionSpanProcessor: SpanProcessor {
  /// Indicates that this processor needs to be called when spans start
  var isStartRequired = true
  /// Indicates that this processor doesn't need to be called when spans end
  var isEndRequired: Bool = false
  /// The attribute key used to store session ID in spans
  var sessionIdKey = "session.id"
  var prevSessionIdKey = "session.previous_id"
  /// Reference to the session manager for retrieving current session ID
  private var sessionManager: AwsSessionManager

  /// Initializes the span processor with a session manager
  /// - Parameter sessionManager: The session manager to use for retrieving session IDs
  init(sessionManager: AwsSessionManager) {
    self.sessionManager = sessionManager
  }

  /// Called when a span starts - adds the current session ID as an attribute
  /// - Parameters:
  ///   - parentContext: The parent span context (unused)
  ///   - span: The span being started
  func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    let session = sessionManager.getSession()
    span.setAttribute(key: sessionIdKey, value: session.id)
    if session.previousId != nil {
      span.setAttribute(key: prevSessionIdKey, value: session.previousId!)
    }
  }

  /// Called when a span ends - no action needed for session tracking
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
