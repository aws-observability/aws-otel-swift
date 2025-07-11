import Foundation

/// Represents an AWS RUM session with a unique identifier and expiration time.
/// Sessions are used to group related telemetry data and track user activity periods.
public struct AwsSession: Equatable {
  /// Unique identifier for the session
  public let id: String
  /// Expiration time for the session
  public let expires: Date
  /// Unique identifier of the user's previous session, if any
  public let previousId: String?

  /// Creates a new AWS session
  /// - Parameters:
  ///   - id: Unique identifier for the session
  ///   - expires: Expiration time for the session
  /// .  - previousId: Unique identifier of the user's previous session, if any
  public init(id: String, expires: Date, previousId: String? = nil) {
    self.id = id
    self.expires = expires
    self.previousId = previousId
  }

  /// Two sessions are considered equal if they have the same ID
  /// - Parameters:
  ///   - lhs: Left-hand side session
  ///   - rhs: Right-hand side session
  /// - Returns: True if sessions have the same ID, prevId, and expires timestamps
  public static func == (lhs: AwsSession, rhs: AwsSession) -> Bool {
    return lhs.expires == rhs.expires && lhs.id == rhs.id && lhs.previousId == rhs.previousId
  }

  /// Checks if the session has expired
  /// - Returns: True if the current time is past the session's expires time
  public func isExpired() -> Bool {
    return expires <= Date()
  }
}
