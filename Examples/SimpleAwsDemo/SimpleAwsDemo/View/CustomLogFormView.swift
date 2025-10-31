import SwiftUI

struct CustomLogFormView: View {
  @ObservedObject var viewModel: LoaderViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var message = "Custom log message"
  @State private var attributes: [AttributePair] = [
    AttributePair(key: "action.type", value: "button_click"),
    AttributePair(key: "screen.name", value: "demo")
  ]

  var body: some View {
    NavigationView {
      Form {
        Section("Log Message") {
          TextField("Enter log message", text: $message)
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
      .navigationTitle("Create Custom Log")
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
            viewModel.createCustomLog(message: message, attributes: attributeDict)
            dismiss()
          }
          .disabled(message.isEmpty)
        }
      }
    }
  }
}

struct AttributePair {
  var key: String
  var value: String
}
