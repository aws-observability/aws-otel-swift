import Foundation

/// Manages unique user identifier with automatic generation and persistence.
/// Provides thread-safe access to UID and handles persistence to UserDefaults.
public class AwsUIDManager {
  private let uidKey = "aws-rum-user-id"
  private let uid: String
  private let lock = NSLock()

  /// Initializes the UID manager and restores or generates UID
  init() {
    if let existingUID = UserDefaults.standard.string(forKey: uidKey) {
      uid = existingUID
    } else {
      uid = UUID().uuidString
      UserDefaults.standard.set(uid, forKey: uidKey)
    }
  }

  /// Gets the current UID in a thread-safe manner
  /// - Returns: The current unique user identifier
  public func getUID() -> String {
    return lock.withLock {
      return uid
    }
  }
}
