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
 * Configuration for export endpoint overrides.
 *
 * Allows customization of the endpoints used for logs and traces,
 * which is useful for testing or custom deployments.
 */
@objc public class AwsExportOverride: NSObject, Codable {
  /// Custom endpoint URL for logs
  public var logs: String?

  /// Custom endpoint URL for traces
  public var traces: String?

  /**
   * Initializes export override configuration.
   *
   * @param logs Custom endpoint URL for logs
   * @param traces Custom endpoint URL for traces
   */
  public init(logs: String? = nil, traces: String? = nil) {
    self.logs = logs
    self.traces = traces
    super.init()
  }

  /// Creates a new AwsExportOverrideBuilder instance
  static func builder() -> AwsExportOverrideBuilder {
    return AwsExportOverrideBuilder()
  }
}

/// Builder for creating AwsExportOverride instances with a fluent API
public class AwsExportOverrideBuilder {
  public private(set) var logs: String?
  public private(set) var traces: String?

  public init() {}

  /// Sets the logs endpoint
  public func with(logs: String?) -> Self {
    self.logs = logs
    return self
  }

  /// Sets the traces endpoint
  public func with(traces: String?) -> Self {
    self.traces = traces
    return self
  }

  /// Builds the AwsExportOverride with the configured settings
  public func build() -> AwsExportOverride {
    return AwsExportOverride(logs: logs, traces: traces)
  }
}
