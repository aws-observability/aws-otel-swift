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

/// Handles persistence of OpenTelemetry sessions to UserDefaults
/// Provides static methods for saving and loading session data
class AwsSessionStore {
  /// UserDefaults key for storing session ID
  static let idKey = "aws-rum-session-id"
  /// UserDefaults key for storing previous session ID
  static let previousIdKey = "aws-rum-session-previous-id"
  /// UserDefaults key for storing session expiry timestamp
  static let expireTimeKey = "aws-rum-session-expire-time"
  /// UserDefaults key for storing session start time
  static let startTimeKey = "aws-rum-session-start-time"
  /// UserDefaults key for storing session timeout
  static let sessionTimeoutKey = "aws-rum-session-timeout"

  /// To avoid writing to disk too often, SessionStore only keeps the current session
  /// in memory and saves to disk on an interval (every 30 seconds).

  /// The most recent session to be saved to disk
  private static var pendingSession: AwsSession?
  /// The previous session
  private static var prevSession: AwsSession?
  /// The interval period after which the current session is saved to disk
  private static let saveInterval: TimeInterval = 30 // in seconds
  /// The timer responsible for saving the current session to disk
  private static var saveTimer: Timer?

  /// Schedules a session to be saved to UserDefaults on the next timer interval
  /// - Parameter session: The session to save
  static func scheduleSave(session: AwsSession) {
    AwsOpenTelemetryLogger.debug("Scheduling session save: \(session.id)")
    pendingSession = session

    if saveTimer == nil {
      AwsOpenTelemetryLogger.debug("Creating save timer with interval: \(saveInterval)s")
      // save initial session
      saveImmediately(session: session)

      // save future sessions on a interval
      saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { _ in
        // only write to disk if it is a new sesssion
        if let pending = pendingSession, prevSession != pending {
          AwsOpenTelemetryLogger.debug("Timer triggered, saving pending session")
          saveImmediately(session: pending)
        }
      }
    }
  }

  /// Immediately saves a session to UserDefaults
  /// - Parameter session: The session to save
  static func saveImmediately(session: AwsSession) {
    AwsOpenTelemetryLogger.debug("Saving session to UserDefaults: \(session.id)")

    // Persist session
    UserDefaults.standard.set(session.id, forKey: idKey)
    UserDefaults.standard.set(session.expireTime, forKey: expireTimeKey)
    UserDefaults.standard.set(session.startTime, forKey: startTimeKey)
    UserDefaults.standard.set(session.previousId, forKey: previousIdKey)
    UserDefaults.standard.set(session.sessionTimeout, forKey: sessionTimeoutKey)

    // update prev session
    prevSession = session
    // clear pending session, since it is now outdated
    pendingSession = nil

    AwsOpenTelemetryLogger.debug("Session saved successfully")
  }

  /// Loads a previously saved session from UserDefaults
  /// - Returns: The saved session if ID, startTime, and expireTime exist. nil otherwise
  static func load() -> AwsSession? {
    AwsOpenTelemetryLogger.debug("Loading session from UserDefaults")

    guard let startTime = UserDefaults.standard.object(forKey: startTimeKey) as? Date,
          let id = UserDefaults.standard.string(forKey: idKey),
          let expireTime = UserDefaults.standard.object(forKey: expireTimeKey) as? Date,
          let sessionTimeout = UserDefaults.standard.object(forKey: sessionTimeoutKey) as? Int
    else {
      AwsOpenTelemetryLogger.debug("No valid session found in UserDefaults")
      return nil
    }

    let previousId = UserDefaults.standard.string(forKey: previousIdKey)
    AwsOpenTelemetryLogger.debug("Found session in UserDefaults: \(id), previous: \(previousId ?? "none")")

    // reset sessions so it does not get overridden in the next scheduled save
    pendingSession = nil
    prevSession = AwsSession(
      id: id,
      expireTime: expireTime,
      previousId: previousId,
      startTime: startTime,
      sessionTimeout: sessionTimeout
    )
    return prevSession
  }

  /// Cleans up timer and UserDefaults
  static func teardown() {
    AwsOpenTelemetryLogger.info("Tearing down AwsSessionStore")
    saveTimer?.invalidate()
    saveTimer = nil
    pendingSession = nil
    prevSession = nil
    UserDefaults.standard.removeObject(forKey: idKey)
    UserDefaults.standard.removeObject(forKey: startTimeKey)
    UserDefaults.standard.removeObject(forKey: expireTimeKey)
    UserDefaults.standard.removeObject(forKey: previousIdKey)
    UserDefaults.standard.removeObject(forKey: sessionTimeoutKey)
    AwsOpenTelemetryLogger.debug("AwsSessionStore teardown complete")
  }
}
