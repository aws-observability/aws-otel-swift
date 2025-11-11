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
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp
import OpenTelemetryProtocolExporterCommon

/**
 * Log record exporter using OTLP exporter with custom HTTP client.
 */
public class AwsRetryableLogExporter: LogRecordExporter {
  private let otlpExporter: OtlpHttpLogExporter

  public init(endpoint: URL, config: AwsExporterConfig = .default) {
    let httpClient = AwsHttpClient(config: config)
    otlpExporter = OtlpHttpLogExporter(
      endpoint: endpoint,
      config: OtlpConfiguration(compression: .gzip),
      httpClient: httpClient
    )
  }

  init(endpoint: URL, config: AwsExporterConfig, httpClient: AwsHttpClient) {
    otlpExporter = OtlpHttpLogExporter(
      endpoint: endpoint,
      config: OtlpConfiguration(compression: .gzip),
      httpClient: httpClient
    )
  }

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    return otlpExporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return otlpExporter.forceFlush(explicitTimeout: explicitTimeout)
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    otlpExporter.shutdown(explicitTimeout: explicitTimeout)
  }
}
