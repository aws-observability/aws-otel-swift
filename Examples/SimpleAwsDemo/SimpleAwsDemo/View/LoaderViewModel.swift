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
import AwsOpenTelemetryAuth
import AWSCognitoIdentity
import AwsOpenTelemetryCore
import Combine

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

  /// Timer for updating the digital clock
  private var clockTimer: AnyCancellable?

  /// Instance of the AWS service handler (non-observable)
  private(set) var awsServiceHandler: AwsServiceHandler?

  private let cognitoPoolId: String
  private let region: String

  /// Date formatter for the digital clock
  private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    return formatter
  }()

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
      // Configure and initialize the Cognito Identity client
      let cognitoConfig = try await CognitoIdentityClient.CognitoIdentityClientConfiguration(region: region)
      let cognitoIdentityClient = CognitoIdentityClient(config: cognitoConfig)

      let credentialsProvider = CognitoCachedCredentialsProvider(
        cognitoPoolId: cognitoPoolId, cognitoClient: cognitoIdentityClient
      )

      awsServiceHandler = try await AwsServiceHandler(
        region: region,
        awsCredentialsProvider: credentialsProvider,
        cognitoIdentityClient: cognitoIdentityClient,
        cognitoPoolId: cognitoPoolId
      )

      isLoading = false
    } catch {
      self.error = error
      isLoading = false
    }
  }

  /// Performs the "List S3 Buckets" operation and updates UI state
  func listS3Buckets() async {
    stopClock()
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
    stopClock()
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

  func showSessionDetails() {
    resultMessage = "Session Details\n\n"

    // Start the digital clock
    startClock()
  }

  func renewSession() {
    AwsSessionManager.shared.getSession()
  }

  /// Starts the digital clock timer
  private func startClock() {
    // Update time immediately
    updateSessionDetails()

    // Cancel existing timer if it exists
    clockTimer?.cancel()

    // Create a new timer that fires every second
    clockTimer = Timer.publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.updateSessionDetails()
      }
  }

  /// Updates the current time string
  private func updateSessionDetails() {
    var currentTime = timeFormatter.string(from: Date())
    var session = AwsSessionManager.shared.peekSession()!
    var sessionId = session.id
    var sessionExpires = timeFormatter.string(from: session.expires)
    var sessionIsExpired = session.isExpired()

    var lines = [
      "current_time=: \(currentTime)",
      "session.expires=\(sessionExpires)",
      "session.isExpired=\(sessionIsExpired)",
      "session.id=\(sessionId)"
    ]

    resultMessage = lines.joined(separator: "\n")
  }

  /// Stops the digital clock timer
  func stopClock() {
    clockTimer?.cancel()
    clockTimer = nil
  }

  // Teardown
  deinit {
    // Use Task to call MainActor-isolated method from deinit
    Task { @MainActor in
      clockTimer?.cancel()
      clockTimer = nil
    }
  }
}
