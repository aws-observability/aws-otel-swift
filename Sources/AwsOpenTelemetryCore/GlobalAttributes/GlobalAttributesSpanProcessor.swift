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
import OpenTelemetrySdk
import OpenTelemetryApi

public class GlobalAttributesSpanProcessor: SpanProcessor {
  public var isStartRequired = true
  public var isEndRequired: Bool = false
  private var globalAttributesManager: GlobalAttributesManager

  public init(globalAttributesManager: GlobalAttributesManager?) {
    self.globalAttributesManager = globalAttributesManager ?? GlobalAttributesProvider.getInstance()
  }

  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    let globalAttributes = globalAttributesManager.getAttributes()
    for (key, value) in globalAttributes {
      span.setAttribute(key: key, value: value)
    }
  }

  public func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
    // No action needed
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    // No cleanup needed
  }

  public func forceFlush(timeout: TimeInterval?) {
    // No action needed
  }
}
