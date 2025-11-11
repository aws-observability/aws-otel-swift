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
import OpenTelemetryProtocolExporterHttp

/**
 * HTTP client with retry logic that conforms to OTLP HTTPClient protocol.
 */
public class AwsHttpClient: HTTPClient {
  private let config: AwsExporterConfig
  private let session: URLSession

  public init(config: AwsExporterConfig = .default, session: URLSession = URLSession(configuration: .default)) {
    self.config = config
    self.session = session
  }

  public func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    AwsInternalLogger.debug("Sending request to: \(request.url?.absoluteString ?? "unknown")")
    executeWithRetry(request: request, attempt: 0, completion: completion)
  }

  private func executeWithRetry(request: URLRequest, attempt: Int, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    let task = session.dataTask(with: request) { [weak self] _, response, error in
      guard let self else { return }

      if let error {
        if attempt < config.maxRetries {
          let backoffDelay = min(pow(2.0, Double(attempt)), 60.0)
          AwsInternalLogger.debug("HTTP request failed with error: \(error), retrying in \(backoffDelay)s (attempt \(attempt + 1)/\(config.maxRetries + 1))")

          DispatchQueue.global().asyncAfter(deadline: .now() + backoffDelay) {
            self.executeWithRetry(request: request, attempt: attempt + 1, completion: completion)
          }
          return
        }
        AwsInternalLogger.debug("HTTP request failed with error: \(error) after \(attempt + 1) attempts")
        completion(.failure(error))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        let error = NSError(domain: "AwsHttpClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        completion(.failure(error))
        return
      }

      let statusCode = httpResponse.statusCode

      if statusCode >= 200, statusCode < 300 {
        AwsInternalLogger.debug("HTTP request succeeded on attempt \(attempt + 1)")
        completion(.success(httpResponse))
        return
      }

      if config.retryableStatusCodes.contains(statusCode), attempt < config.maxRetries {
        let backoffDelay = min(pow(2.0, Double(attempt)), 60.0)
        AwsInternalLogger.debug("HTTP request failed with status \(statusCode), retrying in \(backoffDelay)s (attempt \(attempt + 1)/\(config.maxRetries + 1))")

        DispatchQueue.global().asyncAfter(deadline: .now() + backoffDelay) {
          self.executeWithRetry(request: request, attempt: attempt + 1, completion: completion)
        }
        return
      }

      AwsInternalLogger.debug("HTTP request failed with status \(statusCode) after \(attempt + 1) attempts")
      completion(.success(httpResponse)) // OTLP expects success even on HTTP errors
    }
    task.resume()
  }
}
