import Foundation

/// Handles persistence of AWS RUM sessions to UserDefaults
/// Provides static methods for saving and loading session data
class AwsSessionStore {
  /// UserDefaults key for storing session ID
  static let idKey = "aws-rum-session-id"
  /// UserDefaults key for storing previous session ID
  static let previousIdKey = "aws-rum-session-previous-id"
  /// UserDefaults key for storing session expiry timestamp
  static let expiryKey = "aws-rum-session-expires"

  /// To avoid writing to disk too often, AwsSessionStore only keeps the current session
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
    pendingSession = session

    if saveTimer == nil {
      // save initial session
      saveImmediately(session: session)

      // save future sessions on a interval
      saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { _ in
        // only write to disk if it is a new sesssion
        if pendingSession != nil, prevSession != pendingSession {
          saveImmediately(session: pendingSession!)
        }
      }
    }
  }

  /// Immediately saves a session to UserDefaults
  /// - Parameter session: The session to save
  static func saveImmediately(session: AwsSession) {
    // Persist session
    UserDefaults.standard.set(session.id, forKey: idKey)
    UserDefaults.standard.set(session.expires, forKey: expiryKey)
    UserDefaults.standard.set(session.previousId, forKey: previousIdKey)

    // update prev session
    prevSession = session
    // clear pending session, since it is now outdated
    pendingSession = nil
  }

  /// Loads a previously saved session from UserDefaults
  /// - Returns: The saved session if both ID and expires exist, nil otherwise
  static func load() -> AwsSession? {
    guard let id = UserDefaults.standard.string(forKey: idKey),
          let expires = UserDefaults.standard.object(forKey: expiryKey) as? Date
    else {
      return nil
    }

    // reset sessions so it does not get overridden in the next scheduled save
    pendingSession = nil
    prevSession = AwsSession(id: id, expires: expires, previousId: UserDefaults.standard.string(forKey: previousIdKey))
    return prevSession
  }

  /// Cleans up timer and UserDefaults
  static func teardown() {
    saveTimer?.invalidate()
    saveTimer = nil
    pendingSession = nil
    prevSession = nil
    UserDefaults.standard.removeObject(forKey: idKey)
    UserDefaults.standard.removeObject(forKey: expiryKey)
    UserDefaults.standard.removeObject(forKey: previousIdKey)
  }
}
