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

import SwiftUI

@MainActor
struct LoaderView: View {
  @State private var awsServiceHandler: AwsServiceHandler?
  @State private var error: Error?

  let cognitoPoolId: String
  let region: String

  var body: some View {
    Group {
      if let awsServiceHandler = awsServiceHandler {
        ContentView()
          .environmentObject(awsServiceHandler)
      } else if let error = error {
        Text("Failed to initialize AWS: \(error.localizedDescription)")
      } else {
        ProgressView("Initializing AWS...")
          .task {
            do {
              // 1. Create the credentials provider
              let awsCredentialsProvider = try await AwsCredentialsProvider(
                cognitoPoolId: cognitoPoolId,
                region: region
              )
              // 2. Create the AWS service handler with resolver
              self.awsServiceHandler = try await AwsServiceHandler(
                region: region,
                awsCredentialsProvider: awsCredentialsProvider
              )
            } catch {
              self.error = error
            }
          }
      }
    }
  }
}
