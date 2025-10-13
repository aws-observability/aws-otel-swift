import SwiftUI

struct CustomSpanFormView: View {
  @ObservedObject var viewModel: LoaderViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var spanName = "custom.operation"
  @State private var durationSeconds: Double = .random(in: 1 ... 5)
  @State private var attributes: [AttributePair] = [
    AttributePair(key: "operation.type", value: "user_action"),
    AttributePair(key: "component", value: "demo_app")
  ]

  var body: some View {
    NavigationView {
      Form {
        Section("Span Name") {
          TextField("Enter span name", text: $spanName)
        }

        Section("Duration") {
          HStack {
            Text("Duration: \(String(format: "%.1f", durationSeconds))s")
            Spacer()
          }
          Slider(value: $durationSeconds, in: 0.1 ... 10.0, step: 0.1)
        }

        Section("Attributes") {
          ForEach(attributes.indices, id: \.self) { index in
            HStack {
              TextField("Key", text: $attributes[index].key)
              TextField("Value", text: $attributes[index].value)
              Button("Remove") {
                attributes.remove(at: index)
              }
              .foregroundColor(.red)
            }
          }

          Button("Add Attribute") {
            attributes.append(AttributePair(key: "", value: ""))
          }
        }
      }
      .navigationTitle("Create Custom Span")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Submit") {
            let attributeDict = Dictionary(uniqueKeysWithValues:
              attributes.compactMap { pair in
                pair.key.isEmpty ? nil : (pair.key, pair.value)
              }
            )
            let startTime = Date()
            let endTime = startTime.addingTimeInterval(durationSeconds)
            viewModel.createCustomSpan(name: spanName, startTime: startTime, endTime: endTime, attributes: attributeDict)
            dismiss()
          }
          .disabled(spanName.isEmpty)
        }
      }
    }
  }
}
