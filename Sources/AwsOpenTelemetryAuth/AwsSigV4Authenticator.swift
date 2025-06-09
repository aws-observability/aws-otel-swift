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
  public static func signHeaders(endpoint: String, credentialsProvider: CredentialsProvider, region: String, serviceName: String, body: Data) async -> [String: String] {
    let contentType = "application/x-protobuf"
    let headers = Headers(["Content-Type": contentType])

    let request = HTTPRequest(
      method: .post,
      uri: URIBuilder()
        .withPath(endpoint)
        .build(),
      headers: headers,
      body: .data(body)
    )

    do {
      let credentials = try await credentialsProvider.getCredentials()
      let identity = try AWSCredentialIdentity(crtAWSCredentialIdentity: credentials)
      let config = AWSSigningConfig(
        credentials: identity,
        expiration: TimeInterval(3600),
        signedBodyHeader: .contentSha256,
        signedBodyValue: .empty,
        flags: SigningFlags(
          useDoubleURIEncode: false,
          shouldNormalizeURIPath: true,
          omitSessionToken: false
        ),
        date: .now,
        service: serviceName,
        region: region,
        signatureType: .requestHeaders,
        signingAlgorithm: .sigv4
      )

      // aws-crt-swift will crash or not generate signed header without CommonRuntimeKit init first.
      CommonRuntimeKit.initialize()

      let signer = AWSSigV4Signer()
      guard let signedRequest = await signer.sigV4SignedRequest(requestBuilder: request.toBuilder(), signingConfig: config) else {
        return [:]
      }
      var headers: [String: String] = [:]
      for header in signedRequest.headers.dictionary {
        headers[header.key] = header.value[0]
      }

      return headers
    } catch {
      print("[AwsOpenTelemetryAuth] Error signing request: \(error)")
      return [:]
    }
  }
}
