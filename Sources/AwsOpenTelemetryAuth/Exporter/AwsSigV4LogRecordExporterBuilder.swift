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

public class AwsSigV4LogRecordExporterBuilder {
  private var endpoint: String?
  private var region: String?
  private var serviceName: String?
  private var credentialsProvider: CredentialsProvider?
  private var parentExporter: LogRecordExporter?

  public init() {}

  public func setEndpoint(endpoint: String) -> AwsSigV4LogRecordExporterBuilder {
    self.endpoint = endpoint
    return self
  }

  public func setRegion(region: String) -> AwsSigV4LogRecordExporterBuilder {
    self.region = region
    return self
  }

  public func setServiceName(serviceName: String) -> AwsSigV4LogRecordExporterBuilder {
    self.serviceName = serviceName
    return self
  }

  public func setCredentialsProvider(credentialsProvider: CredentialsProvider) -> AwsSigV4LogRecordExporterBuilder {
    self.credentialsProvider = credentialsProvider
    return self
  }

  public func setParentExporter(parentExporter: LogRecordExporter) -> AwsSigV4LogRecordExporterBuilder {
    self.parentExporter = parentExporter
    return self
  }

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
