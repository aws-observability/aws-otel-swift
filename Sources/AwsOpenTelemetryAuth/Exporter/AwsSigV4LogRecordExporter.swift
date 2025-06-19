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
import OpenTelemetryProtocolExporterHttp
import OpenTelemetryProtocolExporterCommon

/**
 * A log record exporter that adds AWS SigV4 authentication to log export requests.
 *
 * This exporter wraps an OTLP HTTP exporter and ensures that all
 * outgoing requests are signed with AWS SigV4 authentication.
 * It can either use a provided parent exporter or create a default OTLP HTTP exporter.
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

  /// A serial dispatch queue for thread-safe access to log data
  private let queue = DispatchQueue(label: "com.aws.opentelemetry.logDataQueue")

  /// The underlying log record exporter that handles the actual export
  private var parentExporter: LogRecordExporter?

  /// The log records being processed
  private var logData: [ReadableLogRecord] = []

  /**
   * Creates a new AwsSigV4LogRecordExporter.
   *
   * @param endpoint The full URL of the AWS service endpoint
   * @param region The AWS region code
   * @param serviceName The AWS service name
   * @param credentialsProvider The provider that supplies AWS credentials
   * @param parentExporter Optional underlying exporter; if nil, a default OTLP HTTP exporter will be created
   */
  public init(endpoint: String,
              region: String,
              serviceName: String = "rum",
              credentialsProvider: CredentialsProviding,
              parentExporter: LogRecordExporter? = nil) {
    self.endpoint = endpoint
    self.region = region
    self.serviceName = serviceName
    self.credentialsProvider = credentialsProvider
    self.parentExporter = parentExporter
    if self.parentExporter == nil {
      Task {
        self.parentExporter = await createDefaultExporter()
      }
    }
    AwsSigV4Authenticator.configure(credentialsProvider: credentialsProvider, region: region, serviceName: serviceName)
  }

  /**
   * Exports the given log records.
   *
   * This method stores the log records locally and delegates the export operation
   * to the parent exporter.
   *
   * @param logRecords The log records to export
   * @param explicitTimeout Optional timeout for the export operation
   * @returns The result of the export operation
   */
  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    queue.sync { self.logData = logRecords }
    return parentExporter!.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
  }

  /**
   * Forces a flush of any buffered log records.
   *
   * @param explicitTimeout Optional timeout for the flush operation
   * @returns The result of the flush operation
   */
  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return parentExporter!.forceFlush(explicitTimeout: explicitTimeout)
  }

  /**
   * Shuts down the exporter.
   *
   * @param explicitTimeout Optional timeout for the shutdown operation
   */
  public func shutdown(explicitTimeout: TimeInterval?) {
    parentExporter!.shutdown(explicitTimeout: explicitTimeout)
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
   * Creates a default OTLP HTTP log exporter with SigV4 authentication.
   *
   * This method is called when no parent exporter is provided to the constructor.
   * It creates an OTLP HTTP exporter that uses the AwsSigV4RequestInterceptor to
   * sign all outgoing requests.
   *
   * @returns A configured OTLP HTTP log exporter
   */
  private func createDefaultExporter() async -> LogRecordExporter {
    let endpointURL = URL(string: endpoint)!

    let otlpTracesConfig = OtlpConfiguration(
      compression: .none
    )
    URLProtocol.registerClass(AwsSigV4RequestInterceptor.self)
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [AwsSigV4RequestInterceptor.self]
    let session = URLSession(configuration: configuration)

    return OtlpHttpLogExporter(endpoint: endpointURL, config: otlpTracesConfig, useSession: session)
  }
}
