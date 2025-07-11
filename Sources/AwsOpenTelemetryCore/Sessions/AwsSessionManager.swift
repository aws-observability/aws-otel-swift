import Foundation

/// Manages AWS RUM sessions with automatic expiration and persistence.
/// Provides thread-safe access to session information and handles session lifecycle.
/// Sessions are automatically extended on access and persisted to UserDefaults.
public class AwsSessionManager {
  private var sessionLength: Int
  private var session: AwsSession?
  private var lock = NSLock()

  /// Shared singleton instance
  public static var shared = AwsSessionManager()

  /// Default session length in seconds (30 minutes)
  public static var defaultSessionLength: Int = 30 * 60

  /// Initializes the session manager and restores any previous session from disk
  /// - Parameter sessionLength: Duration in seconds for session validity
  init(sessionLength: Int? = defaultSessionLength
  ) {
    self.sessionLength = sessionLength!
    restoreSessionFromDisk()
  }

  /// Configures the session manager with new settings at runtime
  /// - Parameter sessionLength: New session length in seconds, or nil to use default
  public func configure(sessionLength: Int?) {
    self.sessionLength = sessionLength ?? AwsSessionManager.defaultSessionLength
    // Adjust existing session with the new length
    getSession()
  }

  /// Gets the current session, creating or extending it as needed
  /// This method is thread-safe and will extend the session expires time
  /// - Returns: The current active session
  @discardableResult
  public func getSession() -> AwsSession {
    // We only lock once when fetching the current session to expire with thread safety
    return lock.withLock {
      refreshSession()
      return session!
    }
  }

  /// Gets the current session without extending its expires time
  /// - Returns: The current session if one exists, nil otherwise
  public func peekSession() -> AwsSession? {
    return session
  }

  /// Creates a new session with a unique identifier
  private func startSession() {
    session = AwsSession(
      id: UUID().uuidString,
      expires: Date(timeIntervalSinceNow: Double(sessionLength)),
      previousId: session?.id
    )
  }

  /// Refreshes the current session, creating new one if expired or extending existing one
  private func refreshSession() {
    if session == nil || session!.isExpired() {
      // Start new session if none exists
      startSession()
    } else {
      // Otherwise, extend the existing session
      session = AwsSession(id: session!.id, expires: Date(timeIntervalSinceNow: Double(sessionLength)), previousId: session!.previousId)
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
