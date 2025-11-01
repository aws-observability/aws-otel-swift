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
import AwsOpenTelemetryCore

/**
 * Main app view that allows users to trigger AWS operations like
 * listing S3 buckets and retrieving Cognito Identity.
 */
struct ContentView: View {
  @ObservedObject var viewModel: LoaderViewModel
  @State private var showingDemoViewController = false
  @State private var showingCustomLogForm = false
  @State private var showingCustomSpanForm = false

  private func getResultWindowHeight() -> CGFloat {
    if viewModel.isContractTest() {
      return 0
    }
    return 200
  }

  var body: some View {
    NavigationStack {
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
            awsButton(icon: "network", title: "200 HTTP Request") {
              await viewModel.make200Request()
            }

            awsButton(icon: "network", title: "4xx HTTP Request") {
              await viewModel.make4xxRequest()
            }

            awsButton(icon: "network", title: "5xx HTTP Request") {
              await viewModel.make5xxRequest()
            }

            /// UIKit Demo
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

            if viewModel.isNotContractTest() {
              awsButton(icon: "person.circle", title: "Show User Info", action: {
                viewModel.showUserInfo()
              })

              awsButton(icon: "doc.text", title: "Create Custom Log", action: {
                viewModel.showCustomLogForm()
              })

              awsButton(icon: "chart.line.uptrend.xyaxis", title: "Create Custom Span", action: {
                viewModel.showCustomSpanForm()
              })

              // Add navigation to TracedContentView
              NavigationLink(destination: TracedContentView()) {
                HStack {
                  Image(systemName: "chart.line.uptrend.xyaxis")
                  Text("SwiftUI Tracing Demo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
              }

              awsButton(icon: "info.circle", title: "Peek session", action: {
                viewModel.showSessionDetails()
              })

              awsButton(icon: "arrow.clockwise", title: "Renew session", action: {
                viewModel.renewSession()
                viewModel.showSessionDetails()
              })

              awsButton(icon: "exclamationmark.triangle", title: "Simulate ANR (2 sec)") {
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

              awsButton(icon: "tag", title: "Global Attributes", action: {
                viewModel.showGlobalAttributesView()
              })
            }
          }
          .padding(.horizontal)
        }
        .accessibilityIdentifier("SampleScrollView")

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
        .frame(height: getResultWindowHeight())
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()
      }
      .sheet(isPresented: $showingDemoViewController) {
        DemoViewControllerRepresentable()
      }
      .sheet(isPresented: $viewModel.showingCustomLogForm) {
        CustomLogFormView(viewModel: viewModel)
      }
      .sheet(isPresented: $viewModel.showingCustomSpanForm) {
        CustomSpanFormView(viewModel: viewModel)
      }
      .sheet(isPresented: $viewModel.showingGlobalAttributesView) {
        GlobalAttributesView()
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
    override init() {
      super.init()
      isLoading = false
      resultMessage = "Demo results will appear here"
    }

    override func showSessionDetails() {}
    override func renewSession() {}
    override func showUserInfo() {}
    override func showCustomLogForm() {}
    override func showCustomSpanForm() {}
    override func showGlobalAttributesView() {}
  }

  static var previews: some View {
    ContentView(viewModel: MockLoaderViewModel())
      .previewDisplayName("Landing View")
      .padding()
  }
}
