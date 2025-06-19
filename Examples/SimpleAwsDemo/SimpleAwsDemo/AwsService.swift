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
import AWSCore
import AWSS3
import AWSCognitoIdentityProvider

/**
 * Service class to handle AWS API calls
 */
class AwsService: ObservableObject {
  private let cognitoPoolId: String
  private let awsRegion: String

  @Published var isLoading = false
  @Published var resultMessage = "AWS API results will appear here"

  init(cognitoPoolId: String, awsRegion: String) {
    self.cognitoPoolId = cognitoPoolId
    self.awsRegion = awsRegion

    // Configure Cognito
    let credentialsProvider = AWSCognitoCredentialsProvider(regionType: awsRegion.aws_regionTypeValue(), identityPoolId: cognitoPoolId)
    let configuration = AWSServiceConfiguration(region: awsRegion.aws_regionTypeValue(), credentialsProvider: credentialsProvider)
    AWSServiceManager.default().defaultServiceConfiguration = configuration
  }

  /**
   * List S3 buckets
   */
  func listS3Buckets() {
    isLoading = true
    resultMessage = "Loading S3 buckets..."

    let s3 = AWSS3.default()
    let listBucketsRequest = AWSS3ListObjectsRequest()

    s3.listBuckets(listBucketsRequest!).continueWith { [weak self] task in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.isLoading = false

        if let error = task.error {
          self.resultMessage = "Error listing S3 buckets: \(error.localizedDescription)"
          return
        }

        guard let buckets = task.result?.buckets, !buckets.isEmpty else {
          self.resultMessage = "No buckets found"
          return
        }

        // Build a string with bucket information
        var result = "S3 Buckets:\n\n"
        for bucket in buckets {
          let creationDate = bucket.creationDate != nil ? "\(bucket.creationDate!)" : "Unknown"
          result += "- \(bucket.name ?? "Unnamed") (Created: \(creationDate))\n"
        }

        self.resultMessage = result
      }
    }
  }

  /**
   * Get Cognito Identity ID
   */
  func getCognitoIdentityId() {
    isLoading = true
    resultMessage = "Fetching Cognito identity..."

    let cognitoIdentity = AWSCognitoIdentity.default()
    let getIdRequest = AWSCognitoIdentityGetIdInput()
    getIdRequest?.identityPoolId = cognitoPoolId

    cognitoIdentity.getId(getIdRequest!) { [weak self] response, error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.isLoading = false

        if let error = error {
          self.resultMessage = "Error getting Cognito identity: \(error.localizedDescription)"
          return
        }

        guard let identityId = response?.identityId else {
          self.resultMessage = "No identity ID returned"
          return
        }

        self.resultMessage = "Cognito Identity ID: \(identityId)"
      }
    }
  }
}
