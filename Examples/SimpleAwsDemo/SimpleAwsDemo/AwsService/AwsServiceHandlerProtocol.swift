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

/**
 * Protocol defining the interface for AWS service handlers
 *
 * This protocol establishes a contract for classes that handle AWS service interactions.
 * It allows for dependency injection and easier testing by providing a standard
 * interface that can be implemented by real handlers or mock implementations.
 *
 * Conforming types must be actor-isolated to the main actor to ensure thread safety
 * when updating observable properties that may be bound to UI elements.
 */
@MainActor
protocol AwsServiceHandlerProtocol: ObservableObject {
  /**
   * Indicates whether an AWS operation is currently in progress
   *
   * This property should be updated to reflect the loading state of any
   * asynchronous AWS operations, allowing UI components to show appropriate
   * loading indicators.
   */
  var isLoading: Bool { get }

  /**
   * Contains the result message from the most recent AWS operation
   *
   * This property should be updated with human-readable results or error
   * messages after AWS operations complete.
   */
  var resultMessage: String { get }

  /**
   * Lists all S3 buckets in the user's account
   *
   * Implementations should update the `isLoading` and `resultMessage` properties
   * to reflect the operation's progress and outcome.
   */
  func listS3Buckets() async

  /**
   * Retrieves the Cognito Identity ID for the current user
   *
   * Implementations should update the `isLoading` and `resultMessage` properties
   * to reflect the operation's progress and outcome.
   */
  func getCognitoIdentityId() async
}

/**
 * Conformance of AwsServiceHandler to the AwsServiceHandlerProtocol
 *
 * This extension ensures that the concrete AwsServiceHandler class
 * properly implements the protocol interface.
 */
extension AwsServiceHandler: AwsServiceHandlerProtocol {}
