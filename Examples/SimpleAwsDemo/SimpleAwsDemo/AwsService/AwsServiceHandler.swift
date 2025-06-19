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

import AWSClientRuntime
import AWSCognitoIdentity
import AWSS3

import SmithyIdentity

/**
 * A class containing all the code that interacts with the AWS SDK for Swift.
 */
@MainActor
public class AwsServiceHandler: ObservableObject {
  let s3Client: S3Client
  let awsCredentialsProvider: AwsCredentialsProvider

  @Published public var isLoading = false
  @Published public var resultMessage = "AWS API results will appear here"

  public init(region: String, awsCredentialsProvider: AwsCredentialsProvider) async throws {
    self.awsCredentialsProvider = awsCredentialsProvider

    // Get the credential identity resolver
    let credentialIdentityResolver = try await awsCredentialsProvider.getCredentialIdentityResolver()
    let s3Config = try await S3Client.S3ClientConfiguration(
      awsCredentialIdentityResolver: credentialIdentityResolver,
      region: region
    )
    s3Client = S3Client(config: s3Config)
  }

  /// Get S3 buckets
  /// Ref: https://docs.aws.amazon.com/code-library/latest/ug/swift_1_s3_code_examples.html
  public func listS3Buckets() async {
    isLoading = true
    resultMessage = "Loading S3 buckets..."

    do {
      var bucketDetails: [String] = []
      let pages = s3Client.listBucketsPaginated(input: ListBucketsInput())

      for try await page in pages {
        guard let buckets = page.buckets else { continue }
        for bucket in buckets {
          let name = bucket.name ?? "Unnamed"
          let date = bucket.creationDate?.description ?? "Unknown"
          bucketDetails.append("- \(name) (Created: \(date))")
        }
      }
      resultMessage = bucketDetails.isEmpty
        ? "No buckets found"
        : "S3 Buckets:\n\n" + bucketDetails.joined(separator: "\n")
    } catch {
      resultMessage = "Error listing S3 buckets: \(error.localizedDescription)"
    }

    isLoading = false
  }

  /// Get Cognito Identity ID
  public func getCognitoIdentityId() async {
    isLoading = true
    resultMessage = "Fetching Cognito identity..."

    do {
      let input = GetIdInput(identityPoolId: awsCredentialsProvider.cognitoPoolId)
      let output = try await awsCredentialsProvider.cognitoIdentityClient.getId(input: input)

      resultMessage = output.identityId.map { "Cognito Identity ID: \($0)" } ?? "No identity ID returned"

    } catch {
      resultMessage = "Error getting Cognito identity: \(error.localizedDescription)"
    }

    isLoading = false
  }
}
