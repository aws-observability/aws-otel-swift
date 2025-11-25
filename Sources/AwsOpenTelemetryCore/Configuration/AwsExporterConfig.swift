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
import OpenTelemetryProtocolExporterCommon

/**
 * Configuration for AWS OpenTelemetry exporters with retry and batching capabilities.
 */
public struct AwsExporterConfig {
  /// Maximum number of retry attempts (default: 3)
  public let maxRetries: Int

  /// Retry-able HTTP status codes (default: [429, 500, 502, 503, 504])
  public let retryableStatusCodes: Set<Int>

  /// Maximum batch size for exports (default: 100)
  public let maxBatchSize: Int

  /// Maximum in-memory queue size (default: 1048)
  public let maxQueueSize: Int

  /// Batch export interval in seconds (default: 5.0)
  public let batchInterval: TimeInterval

  /// Export timeout in seconds (default: 30.0)
  public let exportTimeout: TimeInterval

  /// Compression type for OTLP exports (default: .gzip)
  public let compression: CompressionType

  /// Default configuration with AWS-optimized settings
  public static let `default` = AwsExporterConfig(
    maxRetries: 3,
    retryableStatusCodes: Set([429, 500, 502, 503, 504]),
    maxBatchSize: 100,
    maxQueueSize: 1048,
    batchInterval: 5.0,
    exportTimeout: 30.0,
    compression: .gzip
  )

  public init(maxRetries: Int = 3,
              retryableStatusCodes: Set<Int> = Set([429, 500, 502, 503, 504]),
              maxBatchSize: Int = 100,
              maxQueueSize: Int = 1048,
              batchInterval: TimeInterval = 5.0,
              exportTimeout: TimeInterval = 30.0,
              compression: CompressionType = .gzip) {
    self.maxRetries = maxRetries
    self.retryableStatusCodes = retryableStatusCodes
    self.maxBatchSize = maxBatchSize
    self.maxQueueSize = maxQueueSize
    self.batchInterval = batchInterval
    self.exportTimeout = exportTimeout
    self.compression = compression
  }
}
