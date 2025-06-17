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
import AwsCommonRuntimeKit
import OpenTelemetryApi
import OpenTelemetrySdk

/**
 * A builder for creating AwsSigV4LogRecordExporter instances.
 *
 * This builder follows the fluent builder pattern to configure and create an exporter
 * that signs log record export requests with AWS SigV4 authentication.
 */
public class AwsSigV4LogRecordExporterBuilder {
  /// The endpoint URL for the AWS service
  private var endpoint: String?

  /// The AWS region where the service is located
  private var region: String?

  /// The name of the AWS service
  private var serviceName: String?

  /// The provider that supplies AWS credentials for signing
  private var credentialsProvider: CredentialsProviding?

  /// The underlying log record exporter that will be wrapped with SigV4 authentication
  private var parentExporter: LogRecordExporter?

  /**
   * Creates a new builder instance with default values.
   */
  public init() {}

  /**
   * Sets the endpoint URL for the AWS service.
   *
   * @param endpoint The full URL of the AWS service endpoint
   * @returns The builder instance for method chaining
   */
  public func setEndpoint(endpoint: String) -> AwsSigV4LogRecordExporterBuilder {
    self.endpoint = endpoint
    return self
  }

  /**
   * Sets the AWS region where the service is located.
   *
   * @param region The AWS region code
   * @returns The builder instance for method chaining
   */
  public func setRegion(region: String) -> AwsSigV4LogRecordExporterBuilder {
    self.region = region
    return self
  }

  /**
   * Sets the name of the AWS service.
   *
   * @param serviceName The AWS service name
   * @returns The builder instance for method chaining
   */
  public func setServiceName(serviceName: String) -> AwsSigV4LogRecordExporterBuilder {
    self.serviceName = serviceName
    return self
  }

  /**
   * Sets the credentials provider for AWS authentication.
   *
   * @param credentialsProvider The provider that supplies AWS credentials
   * @returns The builder instance for method chaining
   */
  public func setCredentialsProvider(credentialsProvider: CredentialsProviding) -> AwsSigV4LogRecordExporterBuilder {
    self.credentialsProvider = credentialsProvider
    return self
  }

  /**
   * Sets the parent log record exporter that will be wrapped with SigV4 authentication.
   *
   * @param parentExporter The underlying log record exporter
   * @returns The builder instance for method chaining
   */
  public func setParentExporter(parentExporter: LogRecordExporter) -> AwsSigV4LogRecordExporterBuilder {
    self.parentExporter = parentExporter
    return self
  }

  /**
   * Builds and returns a new AwsSigV4LogRecordExporter instance.
   *
   * @returns A configured AwsSigV4LogRecordExporter
   * @throws An error if any required configuration is missing
   */
  public func build() throws -> AwsSigV4LogRecordExporter {
    return AwsSigV4LogRecordExporter(
      endpoint: endpoint!,
      region: region!,
      serviceName: serviceName!,
      credentialsProvider: credentialsProvider!,
      parentExporter: parentExporter
    )
  }
}
