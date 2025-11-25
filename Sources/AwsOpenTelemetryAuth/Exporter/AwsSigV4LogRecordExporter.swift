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
import AwsOpenTelemetryCore
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp
import OpenTelemetryProtocolExporterCommon

/**
 * A log record exporter that adds AWS SigV4 authentication to log export requests.
 *
 * This exporter wraps an AwsRetryableLogExporter and ensures that all
 * outgoing requests are signed with AWS SigV4 authentication.
 */
public class AwsSigV4LogRecordExporter: LogRecordExporter {
  /// The endpoint URL for the AWS service
  private let endpoint: String

  /// The AWS region where the service is located
  private let region: String

  /// The name of the AWS service (e.g., "logs")
  private let serviceName: String

  /// The provider that supplies AWS credentials for signing
  private let credentialsProvider: CredentialsProviding

  /// The underlying log record exporter that handles the actual export
  private let exporter: LogRecordExporter

  /**
   * Creates a new AwsSigV4LogRecordExporter.
   *
   * @param endpoint The full URL of the AWS service endpoint
   * @param region The AWS region code
   * @param serviceName The AWS service name
   * @param credentialsProvider The provider that supplies AWS credentials
   */
  public init(endpoint: String? = nil,
              region: String,
              serviceName: String = "rum",
              credentialsProvider: CredentialsProviding) {
    self.endpoint = endpoint ?? AwsExporterUtils.rumEndpoint(region: region)
    self.region = region
    self.serviceName = serviceName
    self.credentialsProvider = credentialsProvider
    exporter = Self.createExporter(endpoint: self.endpoint)
    AwsSigV4Authenticator.configure(credentialsProvider: credentialsProvider, region: region, serviceName: serviceName)
  }

  /**
   * Exports the given log records.
   *
   * @param logRecords The log records to export
   * @param explicitTimeout Optional timeout for the export operation
   * @returns The result of the export operation
   */
  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    return exporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
  }

  /**
   * Forces a flush of any buffered log records.
   *
   * @param explicitTimeout Optional timeout for the flush operation
   * @returns The result of the flush operation
   */
  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return exporter.forceFlush(explicitTimeout: explicitTimeout)
  }

  /**
   * Shuts down the exporter.
   *
   * @param explicitTimeout Optional timeout for the shutdown operation
   */
  public func shutdown(explicitTimeout: TimeInterval?) {
    exporter.shutdown(explicitTimeout: explicitTimeout)
  }

  /**
   * Creates a new builder for configuring an AwsSigV4LogRecordExporter.
   *
   * @returns A new builder instance
   */
  public static func builder() -> AwsSigV4LogRecordExporterBuilder {
    return AwsSigV4LogRecordExporterBuilder()
  }

  /**
   * Creates an AwsRetryableLogExporter with SigV4 authentication.
   *
   * @param endpoint The endpoint URL string
   * @returns A configured AwsRetryableLogExporter with SigV4 authentication
   */
  private static func createExporter(endpoint: String) -> LogRecordExporter {
    let endpointURL = URL(string: endpoint)!

    // Create URLSession with SigV4 interceptor
    URLProtocol.registerClass(AwsSigV4RequestInterceptor.self)
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [AwsSigV4RequestInterceptor.self]
    let session = URLSession(configuration: configuration)

    // Create SigV4-enabled AwsHttpClient
    let httpClient = AwsHttpClient(session: session)

    return AwsRetryableLogExporter(endpoint: endpointURL, config: AwsExporterConfig.default, httpClient: httpClient)
  }
}
