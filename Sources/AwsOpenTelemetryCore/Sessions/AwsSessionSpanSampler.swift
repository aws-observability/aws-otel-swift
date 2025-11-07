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

/// Custom sampler that uses session sampling state for dynamic sampling decisions
public class AwsSessionSpanSampler: Sampler {
  private let sessionManager: AwsSessionManager

  public init(sessionManager: AwsSessionManager? = nil) {
    self.sessionManager = sessionManager ?? AwsSessionManagerProvider.getInstance()
  }

  public func shouldSample(parentContext: SpanContext?,
                           traceId: TraceId,
                           name: String,
                           kind: SpanKind,
                           attributes: [String: AttributeValue],
                           parentLinks: [SpanData.Link]) -> Decision {
    return AwsSessionSamplingDecision(isSampled: sessionManager.isSessionSampled)
  }

  public var description: String {
    return "AwsSessionSpanSampler"
  }
}

/// Decision implementation for session-based sampling
public struct AwsSessionSamplingDecision: Decision {
  public let isSampled: Bool
  public let attributes: [String: AttributeValue] = [:]
}
