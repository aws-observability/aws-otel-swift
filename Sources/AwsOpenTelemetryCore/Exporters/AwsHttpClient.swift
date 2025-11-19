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
  private let otelConfig: AwsOpenTelemetryConfig?

  private static let locationIPs = [
    // United States
    "99.49.114.104", // San Jose, California, USA
    "208.67.222.222", // San Francisco, United States
    "15.181.232.0", // Houston, United States
    "35.111.254.0", // Boardman, United States
    "129.250.35.250", // New York, United States
    "205.171.3.65", // Vassar, United States

    // China
    "223.5.5.5", // Hangzhou, China

    // Germany
    "35.50.192.0", // Frankfurt am Main, Germany

    // Japan
    "34.84.0.0", // Tokyo, Japan

    // India
    "3.108.0.0", // Mumbai, India

    // France
    "35.180.0.0", // Paris, France
    "62.193.42.146", // Alès, Occitanie, France

    // Hong Kong
    "216.244.32.0", // Hong Kong, Hong Kong

    // South Korea
    "210.220.163.82", // Gyeonju, South Korea
    "203.248.252.2", // Suwon, South Korea

    // Sweden
    "193.138.218.74", // Malmo, Sweden

    // Vietnam
    "115.73.220.65", // Ho Chi Minh City, Vietnam

    // Other countries
    "91.239.100.100", // Middelfart, Denmark
    "130.67.15.198", // Asker, Norway
    "200.57.7.57", // Aguascalientes, Mexico
    "181.209.145.2", // Guatemala City, Guatemala
    "41.222.74.42", // Malakal, South Sudan
    "195.229.241.222", // Abu Dhabi, UAE
    "193.136.19.205", // Nine, Portugal
    "185.48.120.3", // Dublin, Ireland
    "89.64.32.64", // Krakow, Poland
    "196.201.214.200", // Nairobi, Kenya
    "197.14.17.134" // Kelaa Kebira, Tunisia
  ]

  public init(config: AwsExporterConfig = .default, session: URLSession = URLSession(configuration: .default), otelConfig: AwsOpenTelemetryConfig? = nil) {
    self.config = config
    self.session = session
    self.otelConfig = otelConfig
  }

  public func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    AwsInternalLogger.debug("Sending request to: \(request.url?.absoluteString ?? "unknown")")
    executeWithRetry(request: request, attempt: 0, completion: completion)
  }

  private func getXForwardedForIP() -> String {
    // Use custom IP if provided in config
    if let customIP = otelConfig?.xForwardedFor {
      return customIP
    }

    // Otherwise, use session-based IP selection
    let sessionManager = AwsSessionManagerProvider.getInstance()
    let sessionId = sessionManager.getSession().id
    let hash = abs(sessionId.hashValue)
    return Self.locationIPs[hash % Self.locationIPs.count]
  }

  private func executeWithRetry(request: URLRequest, attempt: Int, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    var modifiedRequest = request
    modifiedRequest.setValue(getXForwardedForIP(), forHTTPHeaderField: "X-Forwarded-For")

    let task = session.dataTask(with: modifiedRequest) { [weak self] _, response, error in
      guard let self else { return }

      if let error {
        if attempt < config.maxRetries {
          let backoffDelay = min(pow(2.0, Double(attempt)), 60.0)
          AwsInternalLogger.debug("HTTP request failed with error: \(error), retrying in \(backoffDelay)s (attempt \(attempt + 1)/\(config.maxRetries + 1))")

          DispatchQueue.global().asyncAfter(deadline: .now() + backoffDelay) {
            self.executeWithRetry(request: modifiedRequest, attempt: attempt + 1, completion: completion)
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
          self.executeWithRetry(request: modifiedRequest, attempt: attempt + 1, completion: completion)
        }
        return
      }

      AwsInternalLogger.debug("HTTP request failed with status \(statusCode) after \(attempt + 1) attempts")
      completion(.success(httpResponse)) // OTLP expects success even on HTTP errors
    }
    task.resume()
  }
}
