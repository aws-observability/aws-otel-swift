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
 * Configuration for AWS service integration.
 *
 * This class contains all settings required to connect your application to AWS services,
 * including CloudWatch RUM.
 *
 */
@objc public class AwsConfig: NSObject, Codable {
  /// AWS region
  public private(set) var region: String

  /// RUM App Monitor ID
  public private(set) var rumAppMonitorId: String

  /// RUM alias
  public private(set) var rumAlias: String?

  /**
   * Initializes AWS configuration.
   *
   * @param region AWS region
   * @param rumAppMonitorId RUM App Monitor ID
   * @param rumAlias Optional RUM alias
   */
  public init(region: String,
              rumAppMonitorId: String,
              rumAlias: String? = nil) {
    self.region = region
    self.rumAppMonitorId = rumAppMonitorId
    self.rumAlias = rumAlias
    super.init()
  }

  /// Creates a new AwsConfigBuilder instance
  static func builder() -> AwsConfigBuilder {
    return AwsConfigBuilder()
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    region = try container.decode(String.self, forKey: .region)
    rumAppMonitorId = try container.decode(String.self, forKey: .rumAppMonitorId)
    rumAlias = try container.decodeIfPresent(String.self, forKey: .rumAlias)
    super.init()
  }
}

/// Builder for creating AwsConfig instances with a fluent API
public class AwsConfigBuilder {
  public private(set) var region: String?
  public private(set) var rumAppMonitorId: String?
  public private(set) var rumAlias: String?

  public init() {}

  /// Sets the AWS region
  public func with(region: String) -> Self {
    self.region = region
    return self
  }

  /// Sets the RUM App Monitor ID
  public func with(rumAppMonitorId: String) -> Self {
    self.rumAppMonitorId = rumAppMonitorId
    return self
  }

  /// Sets the RUM alias
  public func with(rumAlias: String?) -> Self {
    self.rumAlias = rumAlias
    return self
  }

  /// Builds the AwsConfig with the configured settings
  public func build() -> AwsConfig {
    guard let region, let rumAppMonitorId else {
      fatalError("AwsConfig requires region and rumAppMonitorId to be set")
    }
    return AwsConfig(
      region: region,
      rumAppMonitorId: rumAppMonitorId,
      rumAlias: rumAlias
    )
  }
}
