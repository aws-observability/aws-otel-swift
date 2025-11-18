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
#if canImport(UIKit)
  import UIKit
#endif
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension

/**
 * Utility class for building OpenTelemetry resources with AWS-specific attributes.
 */
public class AwsResourceBuilder {
  /**
   * Builds the resource with AWS RUM attributes.
   *
   * @param config The AWS OpenTelemetry configuration
   * @return A resource with AWS RUM attributes
   */
  public static func buildResource(config: AwsOpenTelemetryConfig) -> Resource {
    var rumResourceAttributes: [String: String] = [
      AwsAttributes.rumAppMonitorId.rawValue: config.aws.rumAppMonitorId,
      AwsAttributes.rumSdkVersion.rawValue: AwsOpenTelemetryAgent.version
    ]

    if let rumAlias = config.aws.rumAlias {
      rumResourceAttributes[AwsAttributes.rumAppMonitorAlias.rawValue] = rumAlias
    }

    let cloudResourceAttributes: [String: String] = [
      SemanticConventions.Cloud.region.rawValue: config.aws.region,
      SemanticConventions.Cloud.provider.rawValue: AwsAttributes.awsCloudProvider.rawValue,
      SemanticConventions.Cloud.platform.rawValue: AwsAttributes.awsRumCloudPlatform.rawValue
    ]

    let deviceResourceAttributes: [String: String] = [
      SemanticConventions.Device.modelName.rawValue: DeviceKitPolyfill.getDeviceName()
    ]

    var resource = DefaultResources().get()
      .merging(other: Resource(attributes: buildAttributeMap(rumResourceAttributes)))
      .merging(other: Resource(attributes: buildAttributeMap(cloudResourceAttributes)))
      .merging(other: Resource(attributes: buildAttributeMap(deviceResourceAttributes)))

    // Add otelResourceAttributes to resource
    if let otelResourceAttributes = config.otelResourceAttributes {
      resource = resource.merging(other: Resource(attributes: buildAttributeMap(otelResourceAttributes)))
    }

    return resource
  }

  /**
   * Converts a string-to-string map to an attribute map.
   *
   * @param map The string-to-string map to convert
   * @return A map of attribute values
   */
  private static func buildAttributeMap(_ map: [String: String]) -> [String: AttributeValue] {
    var attributeMap: [String: AttributeValue] = [:]
    for (key, value) in map {
      attributeMap[key] = AttributeValue(value)
    }
    return attributeMap
  }
}
