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

/**
 * Main app view that allows users to trigger AWS operations like
 * listing S3 buckets and retrieving Cognito Identity.
 */
struct ContentView: View {
  @ObservedObject var viewModel: LoaderViewModel
  @State private var showingDemoViewController = false

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // App title
        Text("ADOT Swift Demo")
          .font(.largeTitle)
          .fontWeight(.bold)
          .padding(.top, 20)
          .padding(.bottom, 10)

        // Scrollable buttons section
        ScrollView {
          LazyVStack(spacing: 12) {
            awsButton(icon: "folder", title: "List S3 Buckets", action: {
              await viewModel.listS3Buckets()
            })

            awsButton(icon: "network", title: "Make 4xx HTTP Request") {
              await viewModel.make4xxRequest()
            }

            awsButton(icon: "network", title: "Make 5xx HTTP Request") {
              await viewModel.make5xxRequest()
            }

            awsButton(icon: "person.badge.key", title: "Get Cognito Identity", action: {
              await viewModel.getCognitoIdentityId()
            })

            Button(action: {
              showingDemoViewController = true
            }, label: {
              HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Show UIKit Demo")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.green)
              .foregroundColor(.white)
              .cornerRadius(10)
            })
            .disabled(viewModel.isLoading)

            awsButton(icon: "info.circle", title: "Peek session", action: {
              viewModel.showSessionDetails()
            })

            awsButton(icon: "arrow.clockwise", title: "Renew session", action: {
              viewModel.renewSession()
              viewModel.showSessionDetails()
            })

            awsButton(icon: "exclamationmark.triangle.filled", title: "Simulate ANR (2 sec)") {
              viewModel.hangApplication(seconds: 2)
            }

            Button(action: {
              let array = []
              _ = array[10] // Index out of bounds
            }, label: {
              HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Trigger Crash")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.red)
              .foregroundColor(.white)
              .cornerRadius(10)
            })
          }
          .padding(.horizontal)
        }

        // Fixed result display at bottom
        VStack {
          if viewModel.isLoading {
            ProgressView()
              .padding(.top, 8)
          }

          ScrollView {
            Text(viewModel.resultMessage)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding()
          }
        }
        .frame(height: 200)
        .background(.white)
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()
      }
      .sheet(isPresented: $showingDemoViewController) {
        DemoViewControllerRepresentable()
      }
    }
  }

  /// Reusable AWS action button with loading state
  @ViewBuilder
  func awsButton(icon: String, title: String, action: @escaping () async -> Void) -> some View {
    Button(action: {
      Task { await action() }
    }, label: {
      HStack {
        Image(systemName: icon)
        Text(title)
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.blue)
      .foregroundColor(.white)
      .cornerRadius(10)
    })
    .disabled(viewModel.isLoading)
  }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
  /// A lightweight mock view model for preview/testing
  @MainActor
  final class MockLoaderViewModel: LoaderViewModel {
    init() {
      // Provide dummy values to satisfy superclass init
      super.init(cognitoPoolId: "mock-pool-id", region: "us-west-2")
      isLoading = false
      resultMessage = "AWS API results will appear here"
    }

    override func listS3Buckets() async {}
    override func getCognitoIdentityId() async {}
    override func showSessionDetails() {}
    override func renewSession() {}
  }

  static var previews: some View {
    ContentView(viewModel: MockLoaderViewModel())
      .previewDisplayName("Landing View")
      .padding()
  }
}
