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
  private let logger: Logger

  /// Queue for storing sessions that were created before instrumentation was initialized.
  /// This allows capturing session events that occur during application startup before
  /// the OpenTelemetry SDK is fully initialized.
  /// Limited to 10 items to prevent memory issues.
  static var queue: [AwsSession] = []

  /// Maximum number of sessions that can be queued before instrumentation is applied
  static let maxQueueSize = 20

  /// Notification name for new session events.
  /// Used to broadcast session creation and expiration events after instrumentation is applied.
  static let sessionEventNotification = Notification.Name(AwsSessionConstants.sessionEventNotification)

  static let instrumentationKey = AwsOpenTelemetryAgent.name + ".session"

  /// Flag to track if the instrumentation has been applied.
  /// Controls whether new sessions are queued or immediately processed via notifications.
  static var isApplied = false

  public init() {
    logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsSessionEventInstrumentation.instrumentationKey)
    AwsOpenTelemetryLogger.debug("Initializing AwsSessionEventInstrumentation")

    guard !AwsSessionEventInstrumentation.isApplied else {
      return
    }

    AwsOpenTelemetryLogger.debug("Applying AwsSessionEventInstrumentation")

    AwsSessionEventInstrumentation.isApplied = true
    // Process any queued sessions
    processQueuedSessions()

    // Start observing for new session notifications
    NotificationCenter.default.addObserver(
      forName: AwsSessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let session = notification.object as? AwsSession {
        self.createSessionEvent(session: session)
      }
    }
    AwsOpenTelemetryLogger.info("AwsSessionEventInstrumentation applied successfully")
  }

  /// Process any sessions that were queued before instrumentation was applied.
  ///
  /// This method is called during the `apply()` process to handle any sessions that
  /// were created before the instrumentation was initialized. It creates log records
  /// for all queued sessions and then clears the queue.
  private func processQueuedSessions() {
    let sessions = AwsSessionEventInstrumentation.queue
    AwsOpenTelemetryLogger.debug("Processing \(sessions.count) queued sessions")

    if sessions.isEmpty {
      AwsOpenTelemetryLogger.debug("No queued sessions to process")
      return
    }

    for session in sessions {
      createSessionEvent(session: session)
    }

    AwsSessionEventInstrumentation.queue.removeAll()
    AwsOpenTelemetryLogger.debug("All queued sessions processed successfully")
  }

  /// Create session start or end log record, depending on if the session is expired.
  ///
  /// This method routes the session to the appropriate handler based on its expiration status.
  /// - Parameter session: The session to create an event for
  private func createSessionEvent(session: AwsSession) {
    if session.isExpired() {
      createSessionEndEvent(session: session)
    } else {
      createSessionStartEvent(session: session)
    }
  }

  /// Create a log record for a `session.start` event.
  ///
  /// Creates an OpenTelemetry log record with session attributes including ID, start time,
  /// and previous session ID (if available).
  /// - Parameter session: The session that has started
  private func createSessionStartEvent(session: AwsSession) {
    AwsOpenTelemetryLogger.debug("Creating session.start event for session ID: \(session.id)")

    var attributes: [String: AttributeValue] = [
      AwsSessionConstants.id: AttributeValue.string(session.id),
      AwsSessionConstants.startTime: AttributeValue.double(session.startTime.timeIntervalSince1970)
    ]

    if let previousId = session.previousId {
      attributes[AwsSessionConstants.previousId] = AttributeValue.string(previousId)
    }

    /// Create `session.start` log record according to otel semantic convention
    /// https://opentelemetry.io/docs/specs/semconv/general/session/
    logger.logRecordBuilder()
      .setBody(AttributeValue.string(AwsSessionConstants.sessionStartEvent))
      .setAttributes(attributes)
      .emit()
  }

  /// Create a log record for a `session.end` event.
  ///
  /// Creates an OpenTelemetry log record with session attributes including ID, start time,
  /// end time, duration, and previous session ID (if available).
  /// - Parameter session: The expired session
  private func createSessionEndEvent(session: AwsSession) {
    guard session.isExpired() else {
      AwsOpenTelemetryLogger.debug("Skipping session.end event for non-expired session ID: \(session.id)")
      return
    }

    guard let endTime = session.endTime,
          let duration = session.duration else {
      return
    }

    AwsOpenTelemetryLogger.debug("Creating session.end event for session ID: \(session.id)")

    var attributes: [String: AttributeValue] = [
      AwsSessionConstants.id: AttributeValue.string(session.id),
      AwsSessionConstants.startTime: AttributeValue.double(session.startTime.timeIntervalSince1970),
      AwsSessionConstants.endTime: AttributeValue.double(endTime.timeIntervalSince1970),
      AwsSessionConstants.duration: AttributeValue.double(duration)
    ]

    if let previousId = session.previousId {
      attributes[AwsSessionConstants.previousId] = AttributeValue.string(previousId)
    }

    /// Create `session.end`` log record according to otel semantic convention
    /// https://opentelemetry.io/docs/specs/semconv/general/session/
    logger.logRecordBuilder()
      .setBody(AttributeValue.string(AwsSessionConstants.sessionEndEvent))
      .setAttributes(attributes)
      .emit()
  }

  /// Add a session to the queue or send notification if instrumentation is already applied.
  ///
  /// This static method is the main entry point for handling new sessions. It either:
  /// - Adds the session to the static queue if instrumentation hasn't been applied yet (max 10 items)
  /// - Posts a notification with the session if instrumentation has been applied
  ///
  /// - Parameter session: The session to process
  static func addSession(session: AwsSession) {
    if isApplied {
      AwsOpenTelemetryLogger.debug("Posting notification for new session event: \(session.id)")
      NotificationCenter.default.post(
        name: sessionEventNotification,
        object: session
      )
    } else {
      /// SessionManager creates sessions before SessionEventInstrumentation is applied,
      /// which the notification observer cannot see. So we need to keep the sessions in a queue.
      if queue.count >= maxQueueSize {
        AwsOpenTelemetryLogger.debug("Queue at max capacity (\(maxQueueSize)), dropping new session: \(session.id)")
        return
      }
      AwsOpenTelemetryLogger.debug("Queueing session event for later processing: \(session.id)")
      queue.append(session)
    }
  }
}
