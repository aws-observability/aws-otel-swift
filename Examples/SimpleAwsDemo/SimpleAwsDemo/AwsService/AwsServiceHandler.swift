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
 * This handler manages AWS service interactions and provides observable state
 * for UI components to display loading status and results.
 */
@MainActor
public class AwsServiceHandler: ObservableObject {
  /// S3 client for interacting with Amazon S3 service
  let s3Client: S3Client

  /// Provider for AWS credentials used by service clients
  let awsCredentialsProvider: AwsCredentialsProvider

  /// Indicates whether an AWS operation is currently in progress
  @Published public var isLoading = false

  /// Contains the result message from the most recent AWS operation
  @Published public var resultMessage = "AWS API results will appear here"

  /**
   * Initializes the AWS service handler with region and credentials provider
   *
   * - Parameters:
   *   - region: The AWS region to use for service clients
   *   - awsCredentialsProvider: Provider that supplies AWS credentials
   *
   * - Throws: Error if unable to initialize the S3 client with valid credentials
   */
  public init(region: String, awsCredentialsProvider: AwsCredentialsProvider) async throws {
    self.awsCredentialsProvider = awsCredentialsProvider

    // Get the credential identity resolver from the provider
    let credentialIdentityResolver = try await awsCredentialsProvider.getCredentialIdentityResolver()

    // Configure and initialize the S3 client with credentials and region
    let s3Config = try await S3Client.S3ClientConfiguration(
      awsCredentialIdentityResolver: credentialIdentityResolver,
      region: region
    )
    s3Client = S3Client(config: s3Config)
  }

  /**
   * Lists all S3 buckets in the user's account
   *
   * This method demonstrates how to make paginated API calls to AWS S3.
   * It retrieves all buckets and formats their details for display.
   *
   * Reference: https://docs.aws.amazon.com/code-library/latest/ug/swift_1_s3_code_examples.html
   */
  public func listS3Buckets() async {
    isLoading = true
    resultMessage = "Loading S3 buckets..."

    do {
      var bucketDetails: [String] = []
      // Use pagination to handle potentially large numbers of buckets
      let pages = s3Client.listBucketsPaginated(input: ListBucketsInput())

      // Process each page of results
      for try await page in pages {
        guard let buckets = page.buckets else { continue }
        for bucket in buckets {
          let name = bucket.name ?? "Unnamed"
          let date = bucket.creationDate?.description ?? "Unknown"
          bucketDetails.append("- \(name) (Created: \(date))")
        }
      }

      // Format the result message based on whether buckets were found
      resultMessage = bucketDetails.isEmpty
        ? "No buckets found"
        : "S3 Buckets:\n\n" + bucketDetails.joined(separator: "\n")
    } catch {
      resultMessage = "Error listing S3 buckets: \(error.localizedDescription)"
    }

    isLoading = false
  }

  /**
   * Retrieves the Cognito Identity ID for the current user
   *
   * This method demonstrates how to interact with Amazon Cognito Identity
   * to retrieve the unique identity ID for the current anonymous or authenticated user.
   */
  public func getCognitoIdentityId() async {
    isLoading = true
    resultMessage = "Fetching Cognito identity..."

    do {
      // Create request to get the identity ID from the Cognito identity pool
      let input = GetIdInput(identityPoolId: awsCredentialsProvider.cognitoPoolId)
      let output = try await awsCredentialsProvider.cognitoIdentityClient.getId(input: input)

      // Format the result based on whether an identity ID was returned
      resultMessage = output.identityId.map { "Cognito Identity ID: \($0)" } ?? "No identity ID returned"

    } catch {
      resultMessage = "Error getting Cognito identity: \(error.localizedDescription)"
    }

    isLoading = false
  }
}
