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
import SwiftUI

/**
 * View model responsible for initializing AWS services and handling API calls.
 *
 * This class owns all observable UI state such as loading indicators, errors,
 * and result messages. It acts as the bridge between the UI and AWS service logic.
 */
@MainActor
class LoaderViewModel: ObservableObject {
  /// Indicates whether an AWS operation is in progress
  @Published var isLoading = true

  /// Stores any error encountered during AWS setup or operations
  @Published var error: Error?

  /// Message displayed to the user representing the result of AWS operations
  @Published var resultMessage: String = "AWS API results will appear here"

  /// Instance of the AWS service handler (non-observable)
  private(set) var awsServiceHandler: AwsServiceHandler?

  private let cognitoPoolId: String
  private let region: String

  /**
   * Initializes the view model with required AWS configuration
   *
   * - Parameters:
   *   - cognitoPoolId: The Cognito Identity Pool ID
   *   - region: AWS region string (e.g., "us-west-2")
   */
  init(cognitoPoolId: String, region: String) {
    self.cognitoPoolId = cognitoPoolId
    self.region = region
  }

  /// Initializes the `AwsServiceHandler` instance and prepares AWS SDK for use
  func initialize() async {
    do {
      let credentialsProvider = try await AwsCredentialsProvider(
        cognitoPoolId: cognitoPoolId,
        region: region
      )

      awsServiceHandler = try await AwsServiceHandler(
        region: region,
        awsCredentialsProvider: credentialsProvider
      )

      isLoading = false
    } catch {
      self.error = error
      isLoading = false
    }
  }

  /// Performs the "List S3 Buckets" operation and updates UI state
  func listS3Buckets() async {
    guard let awsServiceHandler else { return }

    isLoading = true
    resultMessage = "Loading S3 buckets..."
    defer { isLoading = false }

    do {
      let buckets = try await awsServiceHandler.listS3Buckets()
      resultMessage = buckets.isEmpty
        ? "No buckets found"
        : "S3 Buckets:\n\n" + buckets.map { "- \($0.name) (Created: \($0.creationDate))" }.joined(separator: "\n")
    } catch {
      resultMessage = "Error listing S3 buckets: \(error.localizedDescription)"
    }
  }

  /// Performs the "Get Cognito Identity" operation and updates UI state
  func getCognitoIdentityId() async {
    guard let awsServiceHandler else { return }

    isLoading = true
    resultMessage = "Fetching Cognito identity..."
    defer { isLoading = false }

    do {
      let identityId = try await awsServiceHandler.getCognitoIdentityId()
      resultMessage = "Cognito Identity ID: \(identityId)"
    } catch {
      resultMessage = "Error getting Cognito identity: \(error.localizedDescription)"
    }
  }
}
