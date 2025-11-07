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

/// Manages OpenTelemetry sessions with automatic expiration and persistence.
/// Provides thread-safe access to session information and handles session lifecycle.
/// Sessions are automatically extended on access and persisted to UserDefaults.
public class AwsSessionManager {
  private var configuration: AwsSessionConfig
  private var _session: AwsSession?

  private var session: AwsSession? {
    get {
      return sessionQueue.sync { _session }
    }
    set {
      sessionQueue.sync { _session = newValue }
    }
  }

  private let sessionQueue = DispatchQueue(label: "software.amazon.opentelemetry.SessionManager", qos: .utility)
  private var _isSessionSampled: Bool = true

  /// Initializes the session manager and restores any previous session from disk
  /// - Parameter configuration: Session configuration settings
  public init(configuration: AwsSessionConfig = .default) {
    self.configuration = configuration
    restoreSessionFromDisk()
  }

  /// Gets the current session, creating or extending it as needed
  /// This method is thread-safe and will extend the session expireTime time
  /// - Returns: The current active session
  @discardableResult
  public func getSession() -> AwsSession {
    refreshSession()
    return session!
  }

  /// Gets the current session without extending its expireTime time
  /// - Returns: The current session if one exists, nil otherwise
  public func peekSession() -> AwsSession? {
    return session
  }

  /// Gets whether the current session is sampled
  public var isSessionSampled: Bool {
    return _isSessionSampled
  }

  /// Determines if a session should be sampled based on the sample rate
  /// - Parameter sampleRate: Sample rate from 0.0 to 1.0
  /// - Returns: True if session should be sampled, false otherwise
  private func shouldSampleSession(sampleRate: Double) -> Bool {
    return Double.random(in: 0.01 ... 1) <= sampleRate
  }

  /// Creates a new session with a unique identifier
  private func startSession() {
    let now = Date()
    let previousId = session?.id
    let newId = UUID().uuidString

    // Update session sampling based on RNG
    _isSessionSampled = shouldSampleSession(sampleRate: configuration.sessionSampleRate)

    AwsOpenTelemetryLogger.info("Creating new session: \(newId), previous: \(previousId ?? "none")")

    if !_isSessionSampled {
      AwsOpenTelemetryLogger.debug("Session \(newId) will NOT be sampled")
    } else {
      AwsOpenTelemetryLogger.debug("Session \(newId) will be sampled")
    }

    // Store previous session for cleanup outside the lock
    let previousSession = session

    // Create new session
    session = AwsSession(
      id: newId,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: previousId,
      startTime: now,
      sessionTimeout: configuration.sessionTimeout
    )

    /// Queue the previous session for a `session.end` event
    if let previousSession {
      AwsSessionEventInstrumentation.addSession(session: previousSession, eventType: .end)
    }

    // Queue the new session for a `session.start`` event
    AwsSessionEventInstrumentation.addSession(session: session!, eventType: .start)

    // Post notification for session start
    NotificationCenter.default.post(name: SessionStartNotification, object: session!)
  }

  /// Refreshes the current session, creating new one if expired or extending existing one
  private func refreshSession() {
    if session == nil || session!.isExpired() {
      startSession()
    } else {
      // Otherwise, extend the existing session but preserve the startTime
      session = AwsSession(
        id: session!.id,
        expireTime: Date(timeIntervalSinceNow: Double(configuration.sessionTimeout)),
        previousId: session!.previousId,
        startTime: session!.startTime,
        sessionTimeout: configuration.sessionTimeout
      )
    }
    saveSessionToDisk()
  }

  /// Schedules the current session to be persisted to UserDefaults
  private func saveSessionToDisk() {
    if session != nil {
      AwsSessionStore.scheduleSave(session: session!)
    }
  }

  /// Restores a previously saved session from UserDefaults
  private func restoreSessionFromDisk() {
    session = AwsSessionStore.load()
  }
}
