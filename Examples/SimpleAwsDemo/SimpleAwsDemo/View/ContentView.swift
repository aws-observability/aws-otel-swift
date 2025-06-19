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

import AWSCognitoIdentity
import AWSS3

import SmithyIdentity

struct ContentView<T: AwsServiceHandlerProtocol>: View {
  @EnvironmentObject var awsServiceHandler: T

  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        // Title
        Text("AWS OpenTelemetry Demo")
          .font(.largeTitle)
          .fontWeight(.bold)
          .padding(.top, 20)

        // AWS Operation Buttons
        VStack(spacing: 16) {
          Button(action: { // You can't use await inside a Button's action closure directly — that's why we use .task { ... } right after the button.
            Task { await awsServiceHandler.listS3Buckets() }
          }) {
            HStack {
              Image(systemName: "folder")
              Text("List S3 Buckets")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
          .disabled(awsServiceHandler.isLoading)

          Button(action: { // You can't use await inside a Button's action closure directly — that's why we use .task { ... } right after the button.
            Task { await awsServiceHandler.getCognitoIdentityId() }
          }) {
            HStack {
              Image(systemName: "person.badge.key")
              Text("Get Cognito Identity")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
          .disabled(awsServiceHandler.isLoading)
        }
        .padding(.horizontal)

        // Results Display
        ScrollView {
          VStack {
            if awsServiceHandler.isLoading {
              ProgressView()
                .padding()
            }

            Text(awsServiceHandler.resultMessage)
              .padding()
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()

        Spacer()
      }
      .navigationBarTitle("", displayMode: .inline)
      .padding(.bottom)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  @MainActor
  final class MockHandler: AwsServiceHandlerProtocol {
    // Default values are same as AwsServiceHandler
    @Published var isLoading: Bool = false
    @Published var resultMessage: String = "AWS API results will appear here"

    func listS3Buckets() async {}
    func getCognitoIdentityId() async {}
  }

  static var previews: some View {
    ContentView<MockHandler>()
      .environmentObject(MockHandler())
  }
}
