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
      VStack(spacing: 20) {
        // App title
        Text("AWS OpenTelemetry Demo")
          .font(.largeTitle)
          .fontWeight(.bold)
          .padding(.top, 20)

        // AWS Operation Buttons
        VStack(spacing: 16) {
          awsButton(icon: "folder", title: "List S3 Buckets") {
            await viewModel.listS3Buckets()
          }

          awsButton(icon: "person.badge.key", title: "Get Cognito Identity") {
            await viewModel.getCognitoIdentityId()
          }

          // UIKit Demo Button
          Button(action: {
            showingDemoViewController = true
          }) {
            HStack {
              Image(systemName: "chart.line.uptrend.xyaxis")
              Text("Show UIKit Demo")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
          .disabled(viewModel.isLoading)
        }
        .padding(.horizontal)

        // Result Display
        ScrollView {
          VStack {
            if viewModel.isLoading {
              ProgressView()
                .padding()
            }

            Text(viewModel.resultMessage)
              .padding()
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .frame(maxWidth: .infinity)
        .background(.white)
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()

        Spacer()
      }
      .navigationTitle("Title")
      .padding(.bottom)
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
    }) {
      HStack {
        Image(systemName: icon)
        Text(title)
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.blue)
      .foregroundColor(.white)
      .cornerRadius(10)
    }
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
  }

  static var previews: some View {
    ContentView(viewModel: MockLoaderViewModel())
      .previewDisplayName("Landing View")
      .padding()
  }
}
