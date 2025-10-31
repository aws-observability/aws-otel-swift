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

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Custom HTTPClient that uses a specific URLSession
class HTTPClientWithSession: HTTPClient {
  private let session: URLSession

  init(session: URLSession) {
    self.session = session
  }

  func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    let task = session.dataTask(with: request) { _, response, error in
      if let error {
        completion(.failure(error))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(NSError(domain: "HTTPClientError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])))
        return
      }

      completion(.success(httpResponse))
    }
    task.resume()
  }
}
