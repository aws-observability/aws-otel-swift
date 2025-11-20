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
  @State private var isResultCollapsed = true

  private func getResultWindowHeight() -> CGFloat {
    if viewModel.isContractTest() {
      return 0
    }
    return 200
  }

  var body: some View {
    AwsOTelTraceView("ContentView") {
      NavigationStack {
        VStack(spacing: 0) {
          // Sticky collapsible result section
          VStack(spacing: 0) {
            Button(action: {
              withAnimation(.easeInOut(duration: 0.3)) {
                isResultCollapsed.toggle()
              }
            }) {
              HStack {
                Image(systemName: "gearshape")
                  .foregroundColor(.primary)
                  .font(.headline)
                Text("ADOT Swift Demo")
                  .font(.headline)
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: isResultCollapsed ? "chevron.right" : "chevron.down")
                  .foregroundColor(.secondary)
                  .font(.caption)
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 8)
              .background(Color(.systemGray6))
            }

            if !isResultCollapsed {
              ScrollView {
                Text(viewModel.resultMessage.isEmpty || viewModel.resultMessage == "Demo results will appear here" ? "Tap any button above to see telemetry data, network responses, session info, and more..." : viewModel.resultMessage)
                  .font(.system(.caption, design: .monospaced))
                  .foregroundColor(viewModel.resultMessage.isEmpty || viewModel.resultMessage == "Demo results will appear here" ? .secondary : .primary)
                  .textSelection(.enabled)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
              }
              .frame(maxHeight: 120)
              .background(Color(.systemGray6))
            }
          }
          .background(Color(.systemGray6))
          .cornerRadius(6)
          .padding(.horizontal, 8)
          .padding(.top, 4)

          if false {}

          // Scrollable list of actions
          List {
            Section("Network Tests") {
              Button(action: {
                if isResultCollapsed {
                  withAnimation(.easeInOut(duration: 0.3)) {
                    isResultCollapsed = false
                  }
                }
                Task { await viewModel.make200Request() }
              }) {
                HStack {
                  Image(systemName: "network")
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.green)
                    .cornerRadius(6)
                  Text("200 HTTP Request")
                    .foregroundColor(.primary)
                  Spacer()
                }
              }
              .disabled(viewModel.isLoading)

              Button(action: {
                if isResultCollapsed {
                  withAnimation(.easeInOut(duration: 0.3)) {
                    isResultCollapsed = false
                  }
                }
                Task { await viewModel.make4xxRequest() }
              }) {
                HStack {
                  Image(systemName: "network")
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.orange)
                    .cornerRadius(6)
                  Text("4xx HTTP Request")
                    .foregroundColor(.primary)
                  Spacer()
                }
              }
              .disabled(viewModel.isLoading)

              Button(action: {
                if isResultCollapsed {
                  withAnimation(.easeInOut(duration: 0.3)) {
                    isResultCollapsed = false
                  }
                }
                Task { await viewModel.make5xxRequest() }
              }) {
                HStack {
                  Image(systemName: "network")
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red)
                    .cornerRadius(6)
                  Text("5xx HTTP Request")
                    .foregroundColor(.primary)
                  Spacer()
                }
              }
              .disabled(viewModel.isLoading)
            }

            Section("UI Demos") {
              settingsRow(icon: "iphone", title: "UIKit Demo", color: .blue) {
                showingDemoViewController = true
              }

              NavigationLink(destination: TracedContentView()) {
                Label("SwiftUI Tracing Demo", systemImage: "swiftui")
                  .foregroundColor(.primary)
              }
            }

            if viewModel.isNotContractTest() {
              Section("Telemetry") {
                settingsRow(icon: "doc.text", title: "Create Custom Log", color: .purple) {
                  viewModel.showCustomLogForm()
                }

                settingsRow(icon: "chart.line.uptrend.xyaxis", title: "Create Custom Span", color: .indigo) {
                  viewModel.showCustomSpanForm()
                }

                settingsRow(icon: "tag", title: "Global Attributes", color: .teal) {
                  viewModel.showGlobalAttributesView()
                }
              }

              Section("Session") {
                settingsRow(icon: "person.circle", title: "Show User Info", color: .cyan) {
                  viewModel.showUserInfo()
                }

                settingsRow(icon: "info.circle", title: "Peek Session", color: .mint) {
                  viewModel.showSessionDetails()
                }

                settingsRow(icon: "arrow.clockwise", title: "Renew Session", color: .green) {
                  viewModel.renewSession()
                  viewModel.showSessionDetails()
                }
              }

              Section("Testing") {
                Button(action: {
                  viewModel.hangApplication(seconds: 2)
                }) {
                  HStack {
                    Image(systemName: "exclamationmark.triangle")
                      .foregroundColor(.white)
                      .frame(width: 24, height: 24)
                      .background(Color.yellow)
                      .cornerRadius(6)
                    Text("Simulate ANR (2 sec)")
                      .foregroundColor(.primary)
                    Spacer()
                  }
                }
                .disabled(viewModel.isLoading)

                Button(action: {
                  let array: [Int] = []
                  _ = array[10]
                }) {
                  HStack {
                    Image(systemName: "xmark.octagon")
                      .foregroundColor(.white)
                      .frame(width: 24, height: 24)
                      .background(Color.red)
                      .cornerRadius(6)
                    Text("Trigger Crash")
                      .foregroundColor(.primary)
                    Spacer()
                  }
                }
                .disabled(viewModel.isLoading)
              }
            }
          }
          .listStyle(PlainListStyle())
        }

        .sheet(isPresented: $showingDemoViewController) {
          TracedDemoViewControllerRepresentable()
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
        .overlay {
          if viewModel.isLoading {
            ProgressView()
              .scaleEffect(1.5)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(Color.black.opacity(0.3))
          }
        }
      }
    }
  }

  @ViewBuilder
  func settingsRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: {
      if isResultCollapsed {
        withAnimation(.easeInOut(duration: 0.3)) {
          isResultCollapsed = false
        }
      }
      action()
    }) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(.white)
          .frame(width: 24, height: 24)
          .background(color)
          .cornerRadius(6)

        Text(title)
          .foregroundColor(.primary)

        Spacer()
      }
    }
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
