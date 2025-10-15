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

struct ANRFormView: View {
  @ObservedObject var viewModel: LoaderViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var sleepDuration: String = "2.5"
  @State private var hangType: LoaderViewModel.HangType = .threadSleep

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("ANR Simulation")) {
          HStack {
            Text("Duration (seconds):")
            TextField("Duration", text: $sleepDuration)
              .keyboardType(.decimalPad)
              .textFieldStyle(RoundedBorderTextFieldStyle())
          }

          Picker("Hang Type", selection: $hangType) {
            ForEach(LoaderViewModel.HangType.allCases, id: \.self) { type in
              Text(type.rawValue).tag(type)
            }
          }
          .pickerStyle(MenuPickerStyle())

          Text(hangType.description)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Section {
          Button("Simulate Hang") {
            if let duration = Double(sleepDuration), duration > 0 {
              viewModel.hangApplication(seconds: duration, type: hangType)
            }
          }
          .disabled(sleepDuration.isEmpty || Double(sleepDuration) == nil || Double(sleepDuration) ?? 0 <= 0)
        }
      }
      .navigationTitle("Simulate ANR")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }
}
