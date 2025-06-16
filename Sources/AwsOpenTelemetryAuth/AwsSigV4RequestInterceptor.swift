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

public class AwsSigV4RequestInterceptor: URLProtocol {
  private var dataTask: URLSessionDataTask?

  override public class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return AwsSigV4Authenticator.signURLRequestSync(urlRequest: request)
  }

  override public func startLoading() {
    let config = URLSessionConfiguration.default
    config.protocolClasses = []
    let session = URLSession(configuration: config)

    dataTask = session.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self else { return }

      if let error = error {
        self.client?.urlProtocol(self, didFailWithError: error)
        return
      }

      if let response = response {
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      }

      if let data = data {
        self.client?.urlProtocol(self, didLoad: data)
      }

      self.client?.urlProtocolDidFinishLoading(self)
    }

    dataTask?.resume()
  }

  override public func stopLoading() {
    dataTask?.cancel()
  }
}
