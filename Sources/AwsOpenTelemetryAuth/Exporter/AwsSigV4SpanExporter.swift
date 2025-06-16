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

public class AwsSigV4SpanExporter: SpanExporter {
  private var endpoint: String
  private var region: String
  private var serviceName: String
  private var credentialsProvider: CredentialsProvider
  private var parentExporter: SpanExporter?

  private let queue = DispatchQueue(label: "com.aws.opentelemetry.spanDataQueue")
  private var spanData: [SpanData] = []

  public init(endpoint: String,
              region: String,
              serviceName: String,
              credentialsProvider: CredentialsProvider,
              parentExporter: SpanExporter? = nil) {
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
    AwsSigV4Authenticator.configure(endpoint: endpoint, credentialsProvider: credentialsProvider, region: region, serviceName: serviceName)
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    queue.sync { self.spanData = spans }
    return parentExporter!.export(spans: spanData, explicitTimeout: explicitTimeout)
  }

  public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return parentExporter!.flush(explicitTimeout: explicitTimeout)
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    parentExporter!.shutdown(explicitTimeout: explicitTimeout)
  }

  public static func builder() -> AwsSigV4SpanExporterBuilder {
    return AwsSigV4SpanExporterBuilder()
  }

  private func createDefaultExporter() async -> SpanExporter {
    let endpointURL = URL(string: endpoint)!

    let otlpTracesConfig = OtlpConfiguration(
      compression: .none
    )
    URLProtocol.registerClass(HttpRequestInterceptor.self)
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [HttpRequestInterceptor.self]
    let session = URLSession(configuration: configuration)

    return OtlpHttpTraceExporter(endpoint: endpointURL, config: otlpTracesConfig, useSession: session)
  }
}
