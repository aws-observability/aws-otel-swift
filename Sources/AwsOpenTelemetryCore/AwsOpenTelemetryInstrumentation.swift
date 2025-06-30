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
 * Protocol that all AWS OpenTelemetry instrumentations must conform to.
 * This allows the RUM builder to apply instrumentations without knowing their concrete types.
 */
public protocol AwsOpenTelemetryInstrumentationProtocol {
  /**
   * Applies the instrumentation after OpenTelemetry is fully initialized.
   * This method should be idempotent - calling it multiple times should be safe.
   */
  func apply()
}
