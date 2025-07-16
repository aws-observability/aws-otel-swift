/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Manages OpenTelemetry sessions with automatic expiration and persistence.
/// Provides thread-safe access to session information and handles session lifecycle.
/// Sessions are automatically extended on access and persisted to UserDefaults.
public class AwsSessionManager {
  private var configuration: AwsSessionConfiguration
  private var session: AwsSession?
  private var lock = NSLock()

  /// Initializes the session manager and restores any previous session from disk
  /// - Parameter configuration: Session configuration settings
  public init(configuration: AwsSessionConfiguration = .default) {
    AwsOpenTelemetryLogger.debug("Initializing AwsSessionManager with timeout: \(configuration.sessionTimeout)s")
    self.configuration = configuration
    restoreSessionFromDisk()
  }

  /// Gets the current session, creating or extending it as needed
  /// This method is thread-safe and will extend the session expireTime time
  /// - Returns: The current active session
  @discardableResult
  public func getSession() -> AwsSession {
    AwsOpenTelemetryLogger.debug("Getting current session: id=$\(session?.id ?? "nil")")
    // We only lock once when fetching the current session to expire with thread safety
    return lock.withLock {
      refreshSession()
      return session!
    }
  }

  /// Gets the current session without extending its expireTime time
  /// - Returns: The current session if one exists, nil otherwise
  public func peekSession() -> AwsSession? {
    AwsOpenTelemetryLogger.debug("Peeking at current session: \(session?.id ?? "nil")")
    return session
  }

  /// Creates a new session with a unique identifier
  private func startSession() {
    let now = Date()
    let previousId = session?.id
    let newId = UUID().uuidString

    AwsOpenTelemetryLogger.info("Creating new session: \(newId), previous: \(previousId ?? "none")")

    /// Queue the previous session for a `session.end` event
    if session != nil {
      AwsSessionEventInstrumentation.addSession(session: session!)
    }

    session = AwsSession(
      id: newId,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: previousId,
      startTime: now,
      sessionTimeout: configuration.sessionTimeout
    )

    // Queue the new session for a `session.start`` event
    AwsSessionEventInstrumentation.addSession(session: session!)
  }

  /// Refreshes the current session, creating new one if expired or extending existing one
  private func refreshSession() {
    if session == nil || session!.isExpired() {
      // Start new session if none exists or expired
      if session == nil {
        AwsOpenTelemetryLogger.debug("No session exists, creating new one")
      } else {
        AwsOpenTelemetryLogger.debug("Session expired, creating new one")
      }
      startSession()
    } else {
      // Otherwise, extend the existing session but preserve the startTime
      AwsOpenTelemetryLogger.debug("Extending existing session: \(session!.id)")
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
    AwsOpenTelemetryLogger.info("Attempted to restore session from disk id=\(session?.id ?? "none")")
  }
}
