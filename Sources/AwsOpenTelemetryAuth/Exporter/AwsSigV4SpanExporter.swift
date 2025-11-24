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
 * A span exporter that adds AWS SigV4 authentication to span export requests.
 *
 * This exporter wraps an OTLP HTTP exporter and ensures that all
 * outgoing requests are signed with AWS SigV4 authentication.
 */
public class AwsSigV4SpanExporter: SpanExporter {
  /// The endpoint URL for the AWS service
  private let endpoint: String

  /// The AWS region where the service is located
  private let region: String

  /// The name of the AWS service
  private let serviceName: String

  /// The provider that supplies AWS credentials for signing
  private let credentialsProvider: CredentialsProviding

  /// The underlying span exporter that handles the actual export
  private let exporter: SpanExporter

  /**
   * Creates a new AwsSigV4SpanExporter.
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
   * Exports the given spans.
   *
   * @param spans The spans to export
   * @param explicitTimeout Optional timeout for the export operation
   * @returns The result code of the export operation
   */
  public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    AwsInternalLogger.debug("exporting \(spans.count) spans")
    return exporter.export(spans: spans, explicitTimeout: explicitTimeout)
  }

  /**
   * Forces a flush of any buffered spans.
   *
   * @param explicitTimeout Optional timeout for the flush operation
   * @returns The result code of the flush operation
   */
  public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return exporter.flush(explicitTimeout: explicitTimeout)
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
   * Creates a new builder for configuring an AwsSigV4SpanExporter.
   *
   * @returns A new builder instance
   */
  public static func builder() -> AwsSigV4SpanExporterBuilder {
    return AwsSigV4SpanExporterBuilder()
  }

  /**
   * Creates an AwsRetryableSpanExporter with SigV4 authentication.
   *
   * @param endpoint The endpoint URL string
   * @returns A configured AwsRetryableSpanExporter with SigV4 authentication
   */
  private static func createExporter(endpoint: String) -> SpanExporter {
    let endpointURL = URL(string: endpoint)!

    // Create URLSession with SigV4 interceptor
    URLProtocol.registerClass(AwsSigV4RequestInterceptor.self)
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [AwsSigV4RequestInterceptor.self]
    let session = URLSession(configuration: configuration)

    // Create SigV4-enabled AwsHttpClient
    let httpClient = AwsHttpClient(session: session)

    return AwsRetryableSpanExporter(endpoint: endpointURL, config: AwsExporterConfig.default, httpClient: httpClient)
  }
}
