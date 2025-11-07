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

/// Manages unique user identifier with automatic generation and persistence.
/// Provides thread-safe access to UID and handles persistence to UserDefaults.
public class AwsUIDManager {
  private let uidKey = "aws-rum-user-id"
  private var uid: String
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

  public func setUID(uid: String) {
    lock.withLock {
      self.uid = uid
      UserDefaults.standard.set(uid, forKey: uidKey)
    }

    NotificationCenter.default.post(name: AwsUserIdChangeNotification, object: uid)
  }
}
