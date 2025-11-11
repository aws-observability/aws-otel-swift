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
 * Utility class responsible for loading and parsing AWS OpenTelemetry configurations.
 *
 * This class provides methods to load configuration from JSON files and validate
 * the loaded configuration.
 */
@objc public class AwsRumConfigReader: NSObject {
  /// Default configuration file name
  @objc public static let defaultConfigFileName = "aws_config.json"

  /**
   * Loads configuration from the default file path.
   *
   * @return A parsed configuration object, or nil if the file was not found or is invalid
   */
  @objc public static func loadJsonConfig() -> AwsOpenTelemetryConfig? {
    guard let configURL = Bundle.main.url(forResource: defaultConfigFileName, withExtension: nil) else {
      AwsInternalLogger.debug("Configuration file \(defaultConfigFileName) not found in the main bundle")
      return nil
    }

    return loadConfig(from: configURL)
  }

  /**
   * Loads configuration from a specific URL.
   *
   * @param url The URL pointing to the configuration file
   * @return A parsed configuration object, or nil if the file could not be read or parsed
   */
  public static func loadConfig(from url: URL) -> AwsOpenTelemetryConfig? {
    do {
      let data = try Data(contentsOf: url)
      return try parseConfig(from: data)
    } catch {
      AwsInternalLogger.error("Failed to load configuration: \(error)")
      return nil
    }
  }

  /**
   * Parses configuration from JSON data.
   *
   * @param data The JSON data to parse
   * @return A parsed configuration object
   * @throws JSONDecoder.DecodingError if the JSON data is invalid or doesn't match the expected format
   */
  public static func parseConfig(from data: Data) throws -> AwsOpenTelemetryConfig {
    let decoder = JSONDecoder()
    return try decoder.decode(AwsOpenTelemetryConfig.self, from: data)
  }
}
