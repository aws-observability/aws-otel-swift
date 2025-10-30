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

/// Provides thread-safe singleton access to AwsUIDManager.
///
/// Use this provider to ensure consistent UID management across your application.
///
/// Example:
/// ```swift
/// // Access from anywhere in your app
/// let uid = AwsUIDManagerProvider.getInstance().getUID()
/// ```
public class AwsUIDManagerProvider {
  private static var _instance: AwsUIDManager?
  private static let lock = NSLock()

  /// Returns the singleton AwsUIDManager instance or creates a default one.
  ///
  /// Thread-safe method that returns the singleton AwsUIDManager instance.
  /// If no instance exists, creates one with default configuration.
  /// - Returns: The singleton AwsUIDManager instance
  public static func getInstance() -> AwsUIDManager {
    return lock.withLock {
      if _instance == nil {
        AwsInternalLogger.debug("Creating default AwsUIDManager instance")
        _instance = AwsUIDManager()
      }
      return _instance!
    }
  }
}
