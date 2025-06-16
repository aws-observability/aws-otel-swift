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
import AWSSDKHTTPAuth
import SmithyHTTPAuth
import SmithyHTTPAuthAPI
import SmithyHTTPAPI
import SmithyIdentity
import Smithy

public class AwsSigV4Authenticator {
  private static var endpoint: String?
  private static var credentialsProvider: CredentialsProvider?
  private static var region: String?
  private static var serviceName: String?

  public static func configure(endpoint: String,
                               credentialsProvider: CredentialsProvider,
                               region: String,
                               serviceName: String) {
    self.endpoint = endpoint
    self.credentialsProvider = credentialsProvider
    self.region = region
    self.serviceName = serviceName
  }

  public static func signHeaders(urlRequest: URLRequest) async -> URLRequest {
    guard let endpoint = endpoint,
          let credentialsProvider = credentialsProvider,
          let region = region,
          let serviceName = serviceName else {
      fatalError("AwsSigV4Authenticator not configured. Call configure() first.")
    }
    guard let url = urlRequest.url else { return urlRequest }
    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)

    let requestBuilder = HTTPRequestBuilder()
    if let host = urlComponents?.host {
      requestBuilder
        .withHost(host)
        .withHeader(name: "Host", value: host)
    }
    if let path = urlComponents?.path {
      requestBuilder.withPath(path)
    }
    if let port = urlComponents?.port {
      requestBuilder.withPort(UInt16(port))
    }
    if let queryItems = urlComponents?.queryItems {
      let uriQueryItems = queryItems.map { URIQueryItem(name: $0.name, value: $0.value) }
      requestBuilder.withQueryItems(uriQueryItems)
    }
    if let method = urlRequest.httpMethod {
      requestBuilder.withMethod(HTTPMethodType(rawValue: method) ?? .post)
    }
    if let data = urlRequest.httpBodyStream {
      requestBuilder.withBody(ByteStream.data(bodyStreamAsData(bodyStream: data)))
    }
    if let headers = urlRequest.allHTTPHeaderFields {
      for (key, value) in headers {
        requestBuilder.withHeader(name: key, value: value)
      }
    }

    do {
      let credentials = try await credentialsProvider.getCredentials()
      let identity = try AWSCredentialIdentity(crtAWSCredentialIdentity: credentials)

      let config = AWSSigningConfig(
        credentials: identity,
        signedBodyHeader: .contentSha256,
        signedBodyValue: .empty,
        flags: SigningFlags(
          useDoubleURIEncode: false,
          shouldNormalizeURIPath: true,
          omitSessionToken: false
        ),
        date: Date(),
        service: serviceName,
        region: region,
        signatureType: .requestHeaders,
        signingAlgorithm: .sigv4
      )

      CommonRuntimeKit.initialize()

      let signer = AWSSigV4Signer()
      guard let signedRequest = await signer.sigV4SignedRequest(requestBuilder: requestBuilder, signingConfig: config) else {
        return urlRequest
      }

      let request = try await SmithyHTTPAPI.HTTPRequest.makeURLRequest(from: signedRequest)
      return request

    } catch {
      print("[AwsOpenTelemetryAuth] Error signing request: \(error)")
      return urlRequest
    }
  }

  public static func signHeadersSync(urlRequest: URLRequest) -> URLRequest {
    var signedRequest: URLRequest?
    let semaphore = DispatchSemaphore(value: 0)

    Task {
      signedRequest = await signHeaders(urlRequest: urlRequest)
      semaphore.signal()
    }

    semaphore.wait()
    return signedRequest ?? URLRequest(url: URL(string: endpoint ?? "")!)
  }

  public static func bodyStreamAsData(bodyStream: InputStream) -> Data? {
    bodyStream.open()
    defer { bodyStream.close() }

    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    var data = Data()

    while bodyStream.hasBytesAvailable {
      let read = bodyStream.read(&buffer, maxLength: bufferSize)
      if read < 0 {
        return nil
      } else if read == 0 {
        break
      }
      data.append(buffer, count: read)
    }

    return data
  }
}
