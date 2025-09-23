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
import OpenTelemetryApi

public class GlobalAttributesManager {
  private var attributes: [String: AttributeValue] = [:]
  private let lock = NSLock()

  public init() {}

  public func setAttribute(key: String, value: AttributeValue) {
    lock.withLock {
      attributes[key] = value
    }
  }

  public func getAttribute(key: String) -> AttributeValue? {
    return lock.withLock {
      attributes[key]
    }
  }

  public func getAttributes() -> [String: AttributeValue] {
    return lock.withLock {
      attributes
    }
  }

  public func removeAttribute(key: String) {
    lock.withLock {
      attributes.removeValue(forKey: key)
    }
  }

  public func clearAttributes() {
    lock.withLock {
      attributes.removeAll()
    }
  }
}
