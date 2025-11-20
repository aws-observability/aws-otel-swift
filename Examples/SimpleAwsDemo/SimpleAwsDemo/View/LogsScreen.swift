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

struct LogsScreen: View {
  @ObservedObject var viewModel: LoaderViewModel

  var body: some View {
    AwsOTelTraceView("LogsScreen") {
      NavigationStack {
        ScrollView {
          Text(viewModel.resultMessage.isEmpty ? "No logs available yet. Trigger some actions from the Home tab to see logs here." : viewModel.resultMessage)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(viewModel.resultMessage.isEmpty ? .secondary : .primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .navigationTitle("Logs")
        .background(Color(.systemBackground))
      }
    }
  }
}
