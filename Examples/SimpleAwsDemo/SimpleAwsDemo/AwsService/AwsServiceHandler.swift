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
 * This handler manages AWS service interactions.
 *
 * The responsibility of UI state (e.g., loading indicators, error display)
 * has been delegated to a higher-level view model.
 */
public class AwsServiceHandler {
  /// S3 client for interacting with Amazon S3 service
  let s3Client: S3Client

  /// Provider for AWS credentials used by service clients
  let awsCredentialsProvider: AwsCredentialsProvider

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
   * It retrieves all buckets and returns their details as an array of (name, creationDate) tuples.
   *
   * Reference: https://docs.aws.amazon.com/code-library/latest/ug/swift_1_s3_code_examples.html
   *
   * - Returns: Array of bucket name and creation date pairs
   * - Throws: Error if the API call fails
   */
  public func listS3Buckets() async throws -> [(name: String, creationDate: String)] {
    var bucketDetails: [(name: String, creationDate: String)] = []

    // Use pagination to handle potentially large numbers of buckets
    let pages = s3Client.listBucketsPaginated(input: ListBucketsInput())

    // Process each page of results
    for try await page in pages {
      guard let buckets = page.buckets else { continue }
      for bucket in buckets {
        let name = bucket.name ?? "Unnamed"
        let date = bucket.creationDate?.description ?? "Unknown"
        bucketDetails.append((name, date))
      }
    }

    return bucketDetails
  }

  /**
   * Retrieves the Cognito Identity ID for the current user
   *
   * This method demonstrates how to interact with Amazon Cognito Identity
   * to retrieve the unique identity ID for the current anonymous or authenticated user.
   *
   * - Returns: The Cognito Identity ID as a string
   * - Throws: Error if the identity ID cannot be retrieved
   */
  public func getCognitoIdentityId() async throws -> String {
    // Create request to get the identity ID from the Cognito identity pool
    let input = GetIdInput(identityPoolId: awsCredentialsProvider.cognitoPoolId)
    let output = try await awsCredentialsProvider.cognitoIdentityClient.getId(input: input)

    // Return the identity ID if available, otherwise throw an error
    guard let identityId = output.identityId else {
      throw NSError(
        domain: "AwsServiceHandler",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "No identity ID returned"]
      )
    }

    return identityId
  }
}
