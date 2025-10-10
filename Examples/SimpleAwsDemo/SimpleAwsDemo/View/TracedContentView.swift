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
import OpenTelemetryApi

/// Example view demonstrating how to use AWS OpenTelemetry SwiftUI tracing
///
/// This creates a span hierarchy per traced view:
/// Root span: {screenName} (init → onDisappear)
/// ├── {screenName}.body (each body evaluation)
/// ├── {screenName}.onAppear (appear event)
/// └── {screenName}.onDisappear (disappear event)
struct TracedContentView: View {
  @State private var showDetailView = false
  @State private var showProfileView = false
  @State private var showTemporaryView = false

  var body: some View {
    // Example 1: Using the wrapper view
    AwsOTelTraceView("MainScreen",
                     attributes: ["screen_type": "main"]) {
      VStack(spacing: 20) {
        Text("ADOT SwiftUI Demo")
          .font(.title)
          .padding()

        Text("Watch the console for tracing logs!")
          .font(.caption)
          .foregroundColor(.secondary)

        // Example 2: Using the view modifier
        DetailSection()
          .awsOpenTelemetryTrace("DetailSection",
                                 attributes: ["section": "details"])

        // Navigation buttons to demonstrate view lifecycle
        VStack(spacing: 12) {
          Button("Show Detail View (Modal)") {
            showDetailView = true
          }
          .buttonStyle(.borderedProminent)

          Button("Show Profile View (Navigation)") {
            showProfileView = true
          }
          .buttonStyle(.borderedProminent)

          Button("Show Temporary View (3 seconds)") {
            showTemporaryView = true
            // Auto-dismiss after 3 seconds to demonstrate onDisappear
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
              showTemporaryView = false
            }
          }
          .buttonStyle(.bordered)
        }

        Spacer()
      }
      .padding()
    }
    .sheet(isPresented: $showDetailView) {
      DetailModalView()
    }
    .navigationDestination(isPresented: $showProfileView) {
      ProfileView()
    }
    .overlay {
      if showTemporaryView {
        TemporaryOverlayView()
          .transition(.opacity.combined(with: .scale))
          .animation(.easeInOut, value: showTemporaryView)
      }
    }
  }
}

struct DetailSection: View {
  var body: some View {
    VStack {
      Text("Detail Section")
        .font(.headline)
      Text("This section is traced separately")
        .font(.caption)
        .foregroundColor(.secondary)
      Text("It will create its own span hierarchy")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
  }
}

struct DetailModalView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Text("Detail Modal View")
          .font(.largeTitle)
          .padding()

        Text("This modal demonstrates:")
          .font(.headline)

        VStack(alignment: .leading, spacing: 8) {
          Text("• onAppear when modal opens")
          Text("• onDisappear when modal closes")
          Text("• Separate span hierarchy")
          Text("• Modal presentation tracing")
        }
        .font(.body)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)

        Button("Close Modal") {
          dismiss()
        }
        .buttonStyle(.borderedProminent)

        Spacer()
      }
      .padding()
      .navigationTitle("Detail")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .awsOpenTelemetryTrace("DetailModal",
                           attributes: [
                             "presentation_type": AttributeValue.string("modal"),
                             "view_style": AttributeValue.string("detail")
                           ])
  }
}

struct ProfileView: View {
  var body: some View {
    VStack(spacing: 20) {
      Text("Profile View")
        .font(.largeTitle)
        .padding()

      Text("Navigation-based view tracing:")
        .font(.headline)

      VStack(alignment: .leading, spacing: 8) {
        Text("• Creates spans on navigation")
        Text("• Tracks view lifecycle")
        Text("• onDisappear when navigating back")
        Text("• Hierarchical span structure")
      }
      .font(.body)
      .padding()
      .background(Color.green.opacity(0.1))
      .cornerRadius(8)

      Spacer()
    }
    .padding()
    .navigationTitle("Profile")
    .awsOpenTelemetryTrace("ProfileView",
                           attributes: [
                             "user_type": AttributeValue.string("demo"),
                             "navigation_type": AttributeValue.string("push")
                           ])
  }
}

struct TemporaryOverlayView: View {
  var body: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.5)

      Text("Temporary View")
        .font(.title2)
        .fontWeight(.semibold)

      Text("This view will disappear in 3 seconds")
        .font(.caption)
        .foregroundColor(.secondary)

      Text("Watch console for onDisappear span!")
        .font(.caption2)
        .foregroundColor(.blue)
    }
    .padding(30)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .shadow(radius: 10)
    .awsOpenTelemetryTrace("TemporaryOverlay",
                           attributes: [
                             "view_style": AttributeValue.string("overlay"),
                             "auto_dismiss": AttributeValue.bool(true),
                             "duration_seconds": AttributeValue.int(3)
                           ])
  }
}

#Preview {
  NavigationStack {
    TracedContentView()
  }
}
