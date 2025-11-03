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

struct GlobalAttributesView: View {
  @State private var attributes: [String: AttributeValue] = [:]
  @State private var newKey: String = ""
  @State private var newValue: String = ""
  @Environment(\.dismiss) private var dismiss

  private let manager = AwsGlobalAttributesProvider.getInstance()

  var body: some View {
    NavigationView {
      VStack {
        // Add new attribute section
        VStack(alignment: .leading, spacing: 8) {
          Text("Add New Attribute")
            .font(.headline)

          HStack {
            TextField("Key", text: $newKey)
              .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Value", text: $newValue)
              .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Add") {
              addAttribute()
            }
            .disabled(newKey.isEmpty || newValue.isEmpty)
          }
        }
        .padding()

        Divider()

        // Current attributes list
        VStack(alignment: .leading, spacing: 8) {
          Text("Current Global Attributes")
            .font(.headline)

          if attributes.isEmpty {
            Text("No global attributes set")
              .foregroundColor(.gray)
              .italic()
          } else {
            List {
              ForEach(Array(attributes.keys.sorted()), id: \.self) { key in
                HStack {
                  VStack(alignment: .leading) {
                    Text(key)
                      .font(.subheadline)
                      .fontWeight(.medium)
                    Text(attributeValueToString(attributes[key]!))
                      .font(.caption)
                      .foregroundColor(.gray)
                  }

                  Spacer()

                  Button("Remove") {
                    removeAttribute(key: key)
                  }
                  .foregroundColor(.red)
                }
              }
            }
          }
        }
        .padding()

        Spacer()
      }
      .navigationTitle("Global Attributes")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .onAppear {
      loadAttributes()
    }
  }

  private func loadAttributes() {
    attributes = manager.getAttributes()
  }

  private func addAttribute() {
    manager.setAttribute(key: newKey, value: AttributeValue.string(newValue))
    newKey = ""
    newValue = ""
    loadAttributes()
  }

  private func removeAttribute(key: String) {
    manager.removeAttribute(key: key)
    loadAttributes()
  }

  private func attributeValueToString(_ value: AttributeValue) -> String {
    switch value {
    case let .string(str):
      return str
    case let .bool(bool):
      return String(bool)
    case let .int(int):
      return String(int)
    case let .double(double):
      return String(double)
    case let .stringArray(array):
      return array.joined(separator: ", ")
    case let .boolArray(array):
      return array.map(String.init).joined(separator: ", ")
    case let .intArray(array):
      return array.map(String.init).joined(separator: ", ")
    case let .doubleArray(array):
      return array.map { String($0) }.joined(separator: ", ")
    case let .array(attributeArray):
      return attributeArray.description
    case let .set(attributeSet):
      return attributeSet.labels.description
    }
  }
}

struct GlobalAttributesView_Previews: PreviewProvider {
  static var previews: some View {
    GlobalAttributesView()
  }
}
