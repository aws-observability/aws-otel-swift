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
 * Span exporter using OTLP exporter with custom HTTP client.
 */
public class AwsRetryableSpanExporter: SpanExporter {
  private let otlpExporter: OtlpHttpTraceExporter

  public init(endpoint: URL, config: AwsExporterConfig = .default, otelConfig: AwsOpenTelemetryConfig? = nil) {
    let httpClient = AwsHttpClient(config: config, otelConfig: otelConfig)
    otlpExporter = OtlpHttpTraceExporter(
      endpoint: endpoint,
      config: OtlpConfiguration(compression: .none, exportAsJson: true),
      httpClient: httpClient
    )
  }

  init(endpoint: URL, config: AwsExporterConfig, httpClient: AwsHttpClient) {
    otlpExporter = OtlpHttpTraceExporter(
      endpoint: endpoint,
      config: OtlpConfiguration(compression: .none, exportAsJson: true),
      httpClient: httpClient
    )
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return otlpExporter.export(spans: spans, explicitTimeout: explicitTimeout)
  }

  public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return otlpExporter.flush(explicitTimeout: explicitTimeout)
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    otlpExporter.shutdown(explicitTimeout: explicitTimeout)
  }
}
