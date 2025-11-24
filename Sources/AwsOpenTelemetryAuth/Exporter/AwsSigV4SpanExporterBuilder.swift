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
 * A builder for creating AwsSigV4SpanExporter instances.
 *
 * This builder follows the fluent builder pattern to configure and create an exporter
 * that signs span export requests with AWS SigV4 authentication.
 */
public class AwsSigV4SpanExporterBuilder {
  /// The endpoint URL for the AWS service
  private var endpoint: String?

  /// The AWS region where the service is located
  private var region: String?

  /// The name of the AWS service
  private var serviceName: String?

  /// The provider that supplies AWS credentials for signing
  private var credentialsProvider: CredentialsProviding?

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
  public func setEndpoint(endpoint: String) -> AwsSigV4SpanExporterBuilder {
    self.endpoint = endpoint
    return self
  }

  /**
   * Sets the AWS region where the service is located.
   *
   * @param region The AWS region code
   * @returns The builder instance for method chaining
   */
  public func setRegion(region: String) -> AwsSigV4SpanExporterBuilder {
    self.region = region
    return self
  }

  /**
   * Sets the name of the AWS service.
   *
   * @param serviceName The AWS service name
   * @returns The builder instance for method chaining
   */
  public func setServiceName(serviceName: String) -> AwsSigV4SpanExporterBuilder {
    self.serviceName = serviceName
    return self
  }

  /**
   * Sets the credentials provider for AWS authentication.
   *
   * @param credentialsProvider The provider that supplies AWS credentials
   * @returns The builder instance for method chaining
   */
  public func setCredentialsProvider(credentialsProvider: CredentialsProviding) -> AwsSigV4SpanExporterBuilder {
    self.credentialsProvider = credentialsProvider
    return self
  }

  /**
   * Builds and returns a new AwsSigV4SpanExporter instance.
   *
   * @returns A configured AwsSigV4SpanExporter
   * @throws An error if any required configuration is missing
   */
  public func build() throws -> AwsSigV4SpanExporter {
    return AwsSigV4SpanExporter(
      endpoint: endpoint,
      region: region!,
      serviceName: serviceName ?? "rum",
      credentialsProvider: credentialsProvider!
    )
  }
}
