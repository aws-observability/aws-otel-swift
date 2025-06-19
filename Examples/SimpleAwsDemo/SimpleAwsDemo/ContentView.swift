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

struct ContentView: View {
  @EnvironmentObject var awsService: AwsService

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
          Button(action: {
            awsService.listS3Buckets()
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
          .disabled(awsService.isLoading)

          Button(action: {
            awsService.getCognitoIdentityId()
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
          .disabled(awsService.isLoading)
        }
        .padding(.horizontal)

        // Results Display
        ScrollView {
          VStack {
            if awsService.isLoading {
              ProgressView()
                .padding()
            }

            Text(awsService.resultMessage)
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
  static var previews: some View {
    ContentView()
      .environmentObject(AwsService(cognitoPoolId: "us-east-1:sample-id", awsRegion: "us-east-1"))
  }
}
