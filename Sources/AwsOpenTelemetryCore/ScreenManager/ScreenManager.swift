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
import OpenTelemetrySdk

public class AwsScreenManager {
  // queue
  private let queue: DispatchQueue
  private static let queueLabel = "software.amazon.opentelemetry.AwsScreenManager"

  // state
  private var _interaction = 0
  private var _viewDidAppear = false
  private var _currentScreen: String?

  // thread-safe getters

  public var currentScreen: String? {
    get {
      return queue.sync { _currentScreen }
    }
    set {
      queue.sync {
        _currentScreen = newValue
      }
    }
  }

  private var viewDidAppear: Bool {
    get {
      return queue.sync { _viewDidAppear }
    }
    set {
      queue.sync {
        _viewDidAppear = newValue
      }
    }
  }

  private var interaction: Int {
    get {
      return queue.sync { _interaction }
    }
    set {
      queue.sync {
        _interaction = newValue
      }
    }
  }

  // constructor
  init(queue: DispatchQueue = DispatchQueue(label: queueLabel, qos: .utility)) {
    self.queue = queue
  }

  func setCurrent(screen: String) {
    guard screen != currentScreen else {
      AwsInternalLogger.debug("Screen is already set to \(screen)")
      return
    }

    currentScreen = screen
    interaction += 1
    viewDidAppear = false
  }

  func logViewDidAppear(screen: String,
                        type: AwsViewType,
                        timestamp: Date,
                        logger: Logger,
                        additionalAttributes: [String: AttributeValue]? = nil) {
    guard !viewDidAppear else {
      AwsInternalLogger.debug("ViewDidAppear already logged")
      return
    }

    guard screen == _currentScreen else {
      AwsInternalLogger.debug("Screen mismatch: expected \(_currentScreen ?? "nil"), got \(screen)")
      return
    }

    viewDidAppear = true

    var attributes: [String: AttributeValue] = [
      AwsViewDidAppear.screenName: AttributeValue.string(screen),
      AwsViewDidAppear.type: AttributeValue.string(type.rawValue),
      AwsViewDidAppear.interaction: AttributeValue.int(interaction)
    ]

    if let additionalAttributes {
      attributes.merge(additionalAttributes) { _, new in new }
    }

    logger.logRecordBuilder()
      .setEventName(AwsViewDidAppear.name)
      .setTimestamp(timestamp)
      .setAttributes(attributes)
      .emit()
  }
}
