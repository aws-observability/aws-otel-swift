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

/// Enum to specify the type of session event
public enum SessionEventType {
  case start
  case end
}

/// Represents a session event with its associated session and event type
public struct AwsSessionEvent {
  let session: AwsSession
  let eventType: SessionEventType
}

/// Instrumentation for tracking and logging session lifecycle events.
///
/// This class is responsible for creating OpenTelemetry log records for session start and end events.
/// It handles sessions that are created both before and after the instrumentation is initialized by
/// using a queue mechanism and notification system.
///
/// The instrumentation follows these key patterns:
/// - Sessions created before instrumentation is applied are stored in a static queue
/// - Sessions created after instrumentation is applied trigger notifications
/// - All session events are converted to OpenTelemetry log records with appropriate attributes
/// - Session end events include duration and end time attributes
public class AwsSessionEventInstrumentation {
  private static var logger: Logger {
    return OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsSessionEventInstrumentation.instrumentationKey)
  }

  /// Queue for storing session events that were created before instrumentation was initialized.
  /// This allows capturing session events that occur during application startup before
  /// the OpenTelemetry SDK is fully initialized.
  /// Limited to 20 items to prevent memory issues.
  static var queue: [AwsSessionEvent] = []

  /// Maximum number of sessions that can be queued before instrumentation is applied
  static let maxQueueSize: UInt8 = 32

  /// Notification name for new session events.
  /// Used to broadcast session creation and expiration events after instrumentation is applied.
  static let sessionEventNotification = Notification.Name(AwsSessionConstants.sessionEventNotification)

  static var instrumentationKey: String {
    return AwsInstrumentationScopes.SESSION
  }

  /// Flag to track if the instrumentation has been applied.
  /// Controls whether new sessions are queued or immediately processed via notifications.
  static var isApplied = false

  static func install() {
    guard !isApplied else {
      return
    }

    AwsOpenTelemetryLogger.debug("Installing AwsSessionEventInstrumentation")

    isApplied = true
    // Process any queued sessions
    processQueuedSessions()

    AwsOpenTelemetryLogger.info("AwsSessionEventInstrumentation applied successfully")
  }

  /// Process any sessions that were queued before instrumentation was applied.
  ///
  /// This method is called during the `apply()` process to handle any sessions that
  /// were created before the instrumentation was initialized. It creates log records
  /// for all queued sessions and then clears the queue.
  private static func processQueuedSessions() {
    let sessionEvents = AwsSessionEventInstrumentation.queue
    AwsOpenTelemetryLogger.debug("Processing \(sessionEvents.count) queued session events")

    if sessionEvents.isEmpty {
      AwsOpenTelemetryLogger.debug("No queued session events to process")
      return
    }

    for sessionEvent in sessionEvents {
      createSessionEvent(session: sessionEvent.session, eventType: sessionEvent.eventType)
    }

    AwsSessionEventInstrumentation.queue.removeAll()
    AwsOpenTelemetryLogger.debug("All queued session events processed successfully")
  }

  /// Create session start or end log record based on the specified event type.
  ///
  /// - Parameters:
  ///   - session: The session to create an event for
  ///   - eventType: The type of event to create (start or end)
  private static func createSessionEvent(session: AwsSession, eventType: SessionEventType) {
    switch eventType {
    case .start:
      createSessionStartEvent(session: session)
    case .end:
      createSessionEndEvent(session: session)
    }
  }

  /// Create a log record for a `session.start` event.
  ///
  /// Creates an OpenTelemetry log record with session attributes including ID, start time,
  /// and previous session ID (if available).
  /// - Parameter session: The session that has started
  private static func createSessionStartEvent(session: AwsSession) {
    AwsOpenTelemetryLogger.debug("Creating session.start event for session ID: \(session.id)")

    var attributes: [String: AttributeValue] = [
      AwsSessionConstants.id: AttributeValue.string(session.id)
    ]

    if let previousId = session.previousId {
      attributes[AwsSessionConstants.previousId] = AttributeValue.string(previousId)
    }

    /// Create `session.start` log record according to otel semantic convention
    /// https://opentelemetry.io/docs/specs/semconv/general/session/
    logger.logRecordBuilder()
      .setEventName(AwsSessionConstants.sessionStartEvent)
      .setAttributes(attributes)
      .setTimestamp(session.startTime)
      .emit()
  }

  /// Create a log record for a `session.end` event.
  ///
  /// Creates an OpenTelemetry log record with session attributes including ID, start time,
  /// end time, duration, and previous session ID (if available).
  /// - Parameter session: The expired session
  private static func createSessionEndEvent(session: AwsSession) {
    guard let endTime = session.endTime else {
      AwsOpenTelemetryLogger.debug("Skipping session.end event for session without end time/duration: \(session.id)")
      return
    }

    AwsOpenTelemetryLogger.debug("Creating session.end event for session ID: \(session.id)")

    var attributes: [String: AttributeValue] = [
      AwsSessionConstants.id: AttributeValue.string(session.id)
    ]

    if let previousId = session.previousId {
      attributes[AwsSessionConstants.previousId] = AttributeValue.string(previousId)
    }

    /// Create `session.end`` log record according to otel semantic convention
    /// https://opentelemetry.io/docs/specs/semconv/general/session/
    logger.logRecordBuilder()
      .setEventName(AwsSessionConstants.sessionEndEvent)
      .setAttributes(attributes)
      .setTimestamp(endTime)
      .emit()
  }

  /// Add a session to the queue or send notification if instrumentation is already applied.
  ///
  /// This static method is the main entry point for handling new sessions. It either:
  /// - Adds the session to the static queue if instrumentation hasn't been applied yet (max 10 items)
  /// - Posts a notification with the session if instrumentation has been applied
  ///
  /// - Parameter session: The session to process
  static func addSession(session: AwsSession, eventType: SessionEventType) {
    if isApplied {
      AwsOpenTelemetryLogger.debug("Posting notification for \(eventType) session event: \(session.id)")
      createSessionEvent(session: session, eventType: eventType)
    } else {
      /// SessionManager creates sessions before SessionEventInstrumentation is applied,
      /// which the notification observer cannot see. So we need to keep the sessions in a queue.
      if queue.count >= maxQueueSize {
        AwsOpenTelemetryLogger.debug("Queue at max capacity (\(maxQueueSize)), dropping new session event: \(session.id)")
        return
      }
      AwsOpenTelemetryLogger.debug("Queueing \(eventType) session event for later processing: \(session.id)")
      queue.append(AwsSessionEvent(session: session, eventType: eventType))
    }
  }
}
