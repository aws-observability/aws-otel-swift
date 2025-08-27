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

/**
 * A URL protocol interceptor that automatically signs outgoing requests with AWS SigV4 authentication.
 *
 * This class extends URLProtocol to intercept network requests and apply AWS Signature Version 4
 * authentication before they are sent. It can be registered with URLSession to automatically
 * authenticate all requests to AWS services without modifying the original request code.
 */
public class AwsSigV4RequestInterceptor: URLProtocol {
  /// The underlying data task that will execute the signed request
  private var dataTask: URLSessionDataTask?

  /**
   * Determines whether this protocol can handle the given request.
   * This implementation always returns true, meaning it will attempt to handle all requests.
   *
   * @param request The request to evaluate
   * @returns True if this protocol can handle the request
   */
  override public class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  /**
   * Returns a canonical version of the request, which in this case is the request signed with AWS SigV4.
   *
   * This method is called by the URL loading system to get the actual request that should be sent.
   * It delegates to the AwsSigV4Authenticator to apply SigV4 signatures to the request.
   *
   * @param request The original request
   * @returns The request with AWS SigV4 authentication headers added
   */
  override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return AwsSigV4Authenticator.signURLRequestSync(urlRequest: request)
  }

  /**
   * Starts loading the request.
   *
   * This method creates a new URLSession that doesn't use this interceptor (to avoid infinite recursion)
   * and executes the signed request. It forwards all responses, data, and errors back to the client.
   */
  override public func startLoading() {
    let config = URLSessionConfiguration.default
    config.protocolClasses = []
    let session = URLSession(configuration: config)

    dataTask = session.dataTask(with: request) { [weak self] data, response, error in
      guard let self else { return }

      if let error {
        client?.urlProtocol(self, didFailWithError: error)
        return
      }

      if let response {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      }

      if let data {
        client?.urlProtocol(self, didLoad: data)
      }

      client?.urlProtocolDidFinishLoading(self)
    }

    dataTask?.resume()
  }

  /**
   * Stops loading the request.
   *
   * This method cancels the underlying data task if it's still in progress.
   */
  override public func stopLoading() {
    dataTask?.cancel()
  }
}
