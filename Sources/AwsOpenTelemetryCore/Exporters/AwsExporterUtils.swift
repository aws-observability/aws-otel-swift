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
 * Utility functions for AWS OpenTelemetry exporters.
 */
public enum AwsExporterUtils {
  /**
   * Builds the default AWS CloudWatch RUM endpoint URL for the specified region.
   *
   * @param region The AWS region code
   * @return The RUM endpoint URL string
   */
  public static func rumEndpoint(region: String) -> String {
    return "https://dataplane.rum.\(region).amazonaws.com/v1/rum"
  }
}
