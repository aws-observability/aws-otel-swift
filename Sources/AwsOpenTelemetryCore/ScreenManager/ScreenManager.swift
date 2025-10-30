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

public struct AwsScreenView {
  let type: String
  let name: String
  let timestamp: Date
}

public class AwsScreenManager {
  private(set) var interaction = 0
  public private(set) var previousView: String?
  private let queue: DispatchQueue
  private static let queueLabel = "software.amazon.opentelemetry.AwsScreenManager"

  init(queue: DispatchQueue = DispatchQueue(label: queueLabel, qos: .utility)) {
    self.queue = queue
  }

  private static var logger: Logger {
    return OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsInstrumentationScopes.SCREEN_MANAGER)
  }

  func logViewDidAppear(screen: String,
                        type: AwsViewType,
                        timestamp: Date,
                        additionalAttributes: [String: AttributeValue]? = nil,
                        logger: Logger = logger) {
    queue.async {
      var attributes: [String: AttributeValue] = [
        AwsViewDidAppear.screenName: AttributeValue.string(screen),
        AwsViewDidAppear.type: AttributeValue.string(type.rawValue),
        AwsViewDidAppear.interaction: AttributeValue.int(self.interaction)
      ]

      if let previousView = self.previousView {
        attributes[AwsViewDidAppear.parentName] = AttributeValue.string(previousView)
      }

      if let additionalAttributes {
        attributes.merge(additionalAttributes) { _, new in new }
      }

      logger.logRecordBuilder()
        .setEventName(AwsViewDidAppear.name)
        .setTimestamp(timestamp)
        .setAttributes(attributes)
        .emit()

      self.previousView = screen
      self.interaction += 1
    }
  }
}
