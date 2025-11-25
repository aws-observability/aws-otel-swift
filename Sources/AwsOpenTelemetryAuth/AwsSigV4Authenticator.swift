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
import AwsOpenTelemetryCore
import AWSSDKHTTPAuth
import SmithyHTTPAuth
import SmithyHTTPAuthAPI
import SmithyHTTPAPI
import SmithyIdentity
import Smithy

/**
 * A utility class that provides AWS Signature Version 4 (SigV4) authentication functionality.
 *
 * This authenticator signs HTTP requests with AWS SigV4 signatures to authenticate
 * requests to AWS services. It must be configured with credentials, region, and service
 * information before use.
 */
public class AwsSigV4Authenticator {
  /// The credentials provider used to obtain AWS credentials for signing
  private static var credentialsProvider: CredentialsProviding?

  /// The AWS region where the service is located
  private static var region: String?

  /// The name of the AWS service being accessed
  private static var serviceName: String?

  /**
   * Configures the authenticator with the necessary credentials and service information.
   *
   * This method must be called before attempting to sign any requests.
   *
   * @param credentialsProvider The provider that supplies AWS credentials for signing
   * @param region The AWS region where the service is located
   * @param serviceName The name of the AWS service being accessed
   */
  public static func configure(credentialsProvider: CredentialsProviding,
                               region: String,
                               serviceName: String) {
    self.credentialsProvider = credentialsProvider
    self.region = region
    self.serviceName = serviceName
  }

  /**
   * Signs a URL request with AWS Signature Version 4 (SigV4) authentication.
   *
   * This asynchronous method retrieves credentials and applies SigV4 signing to the provided
   * URL request. It converts the URLRequest to a format compatible with the AWS signing libraries,
   * applies the signature, and returns a new request with the appropriate authentication headers.
   *
   * @param urlRequest The original URL request to be signed
   * @returns A new URL request with AWS SigV4 authentication headers added
   */
  private static func signURLRequest(urlRequest: URLRequest) async -> URLRequest {
    // Verify that the authenticator has been properly configured
    guard let credentialsProvider,
          let region,
          let serviceName else {
      AwsInternalLogger.error("AwsSigV4Authenticator not configured. Call configure() first.")
      return urlRequest
    }
    guard let url = urlRequest.url else { return urlRequest }
    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)

    // Convert URLRequest to HTTPRequestBuilder format for signing
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
      // Retrieve credentials and create identity for signing
      let credentials: Credentials
      do {
        credentials = try await credentialsProvider.getCredentials()
      } catch {
        AwsInternalLogger.error("Error getting credentials: \(error)")
        return urlRequest
      }
      let identity = try AWSCredentialIdentity(crtAWSCredentialIdentity: credentials)

      // Configure the signing parameters
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

      // aws-crt-swift will crash or not generate signed header without CommonRuntimeKit init first.
      CommonRuntimeKit.initialize()

      // Sign the request and convert back to URLRequest
      let signer = AWSSigV4Signer()
      guard let signedRequest = await signer.sigV4SignedRequest(requestBuilder: requestBuilder, signingConfig: config) else {
        return urlRequest
      }
      let request = try await SmithyHTTPAPI.HTTPRequest.makeURLRequest(from: signedRequest)

      return request
    } catch {
      AwsInternalLogger.error("Error signing request: \(error)")
      return urlRequest
    }
  }

  /**
   * Synchronously signs a URL request with AWS Signature Version 4 (SigV4) authentication.
   *
   * This method provides a synchronous wrapper around the asynchronous signing process,
   * making it easier to use in contexts where async/await is not available or desired.
   * It uses a semaphore to wait for the asynchronous signing operation to complete.
   *
   * @param urlRequest The original URL request to be signed
   * @returns A new URL request with AWS SigV4 authentication headers added
   */
  public static func signURLRequestSync(urlRequest: URLRequest) -> URLRequest {
    var signedRequest: URLRequest?
    let semaphore = DispatchSemaphore(value: 0)

    Task {
      signedRequest = await signURLRequest(urlRequest: urlRequest)
      semaphore.signal()
    }

    semaphore.wait()
    return signedRequest ?? urlRequest
  }

  /**
   * Converts an InputStream to Data.
   *
   * This utility method reads the contents of an input stream and converts it to a Data object,
   * which is needed for the request signing process. It handles the stream in chunks to efficiently
   * process streams of any size.
   *
   * @param bodyStream The input stream containing the request body data
   * @returns The contents of the stream as a Data object, or nil if reading fails
   */
  private static func bodyStreamAsData(bodyStream: InputStream) -> Data? {
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
