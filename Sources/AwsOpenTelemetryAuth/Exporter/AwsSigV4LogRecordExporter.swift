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

public class AwsSigV4LogRecordExporter: LogRecordExporter {
  private var endpoint: String
  private var region: String
  private var serviceName: String
  private var credentialsProvider: CredentialsProvider
  private var parentExporter: LogRecordExporter?

  private let queue = DispatchQueue(label: "com.aws.opentelemetry.logDataQueue")
  private var logData: [ReadableLogRecord] = []

  public init(endpoint: String,
              region: String,
              serviceName: String,
              credentialsProvider: CredentialsProvider,
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
  }

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    queue.sync { self.logData = logRecords }
    return parentExporter!.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return parentExporter!.forceFlush(explicitTimeout: explicitTimeout)
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    parentExporter!.shutdown(explicitTimeout: explicitTimeout)
  }

  public static func builder() -> AwsSigV4LogRecordExporterBuilder {
    return AwsSigV4LogRecordExporterBuilder()
  }

  private func createDefaultExporter() async -> LogRecordExporter {
    let endpointURL = URL(string: endpoint)!

    let headers = await getHeaders()
    let headerTuples = headers.map { ($0.key, $0.value) }

    return OtlpHttpLogExporter(endpoint: endpointURL, envVarHeaders: headerTuples)
  }

  private func getHeaders() async -> [String: String] {
    let body = queue.sync { self.logData }
    var jsonData: Data

    do {
      jsonData = try JSONEncoder().encode(body)
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
      }
    } catch {
      print("Failed to serialize LogRecord as JSON: \(error)")
      return [:]
    }

    return await AwsSigV4Authenticator.signHeaders(endpoint: endpoint, credentialsProvider: credentialsProvider, region: region, serviceName: serviceName, body: jsonData)
  }
}
