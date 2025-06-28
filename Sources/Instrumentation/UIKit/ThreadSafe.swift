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

/**
 * A property wrapper that provides thread-safe access to a wrapped value.
 *
 * This property wrapper uses NSLock to ensure that read and write operations
 * on the wrapped value are atomic and thread-safe. It's particularly useful
 * for protecting shared state in concurrent environments.
 *
 * ## Usage
 *
 * ```swift
 * class MyClass {
 *   @ThreadSafe var counter: Int = 0
 *   @ThreadSafe var items: [String] = []
 * }
 * ```
 *
 * ## Thread Safety
 *
 * - **Read Operations**: Protected by lock acquisition before reading
 * - **Write Operations**: Protected by lock acquisition before writing
 * - **Atomic Access**: Each individual read/write operation is atomic
 * - **Performance**: Uses NSLock for efficient synchronization
 *
 * ## Important Notes
 *
 * While individual operations are thread-safe, compound operations are not:
 *
 * ```swift
 * // NOT thread-safe for compound operations
 * if myClass.counter > 0 {
 *   myClass.counter -= 1  // Value might change between check and decrement
 * }
 *
 * // Better approach for compound operations
 * let currentValue = myClass.counter
 * if currentValue > 0 {
 *   // Use external synchronization for compound operations
 * }
 * ```
 */
@propertyWrapper
class ThreadSafe<T> {
  /// The underlying value being protected
  private var value: T

  /// NSLock for synchronizing access to the value
  private let lock = NSLock()

  /**
   * Initializes the thread-safe wrapper with an initial value.
   *
   * @param wrappedValue The initial value to wrap and protect
   */
  init(wrappedValue: T) {
    value = wrappedValue
  }

  /**
   * Provides thread-safe access to the wrapped value.
   *
   * Both getter and setter operations are protected by the same lock,
   * ensuring atomic access to the underlying value.
   */
  var wrappedValue: T {
    get {
      lock.lock()
      defer { lock.unlock() }
      return value
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      value = newValue
    }
  }
}
