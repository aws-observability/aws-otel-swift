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
            // Use signRequest method with the appropriate parameters
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
            // Extract headers from the signed request
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
