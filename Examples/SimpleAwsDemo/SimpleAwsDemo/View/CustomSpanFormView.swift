import SwiftUI

struct CustomSpanFormView: View {
  @ObservedObject var viewModel: LoaderViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var spanName = "custom.operation"
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
            viewModel.createCustomSpan(name: spanName, attributes: attributeDict)
            dismiss()
          }
          .disabled(spanName.isEmpty)
        }
      }
    }
  }
}
