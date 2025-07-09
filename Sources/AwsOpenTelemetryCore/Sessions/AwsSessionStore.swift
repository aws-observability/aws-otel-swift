import Foundation

/// Handles persistence of AWS RUM sessions to UserDefaults
/// Provides static methods for saving and loading session data
class AwsSessionStore {
  /// UserDefaults key for storing session ID
  static let idKey = "aws-rum-session-id"
  /// UserDefaults key for storing session expires
  static let expiryKey = "aws-rum-session-expires"

  /// Saves a session to UserDefaults, overwriting any existing session
  /// - Parameter session: The session to save
  static func save(session: AwsSession) {
    UserDefaults.standard.set(session.id, forKey: idKey)
    UserDefaults.standard.set(session.expires, forKey: expiryKey)
  }

  /// Loads a previously saved session from UserDefaults
  /// - Returns: The saved session if both ID and expires exist, nil otherwise
  static func load() -> AwsSession? {
    guard let id = UserDefaults.standard.string(forKey: idKey),
          let expires = UserDefaults.standard.object(forKey: expiryKey) as? Date
    else {
      return nil
    }

    return AwsSession(id: id, expires: expires)
  }
}
