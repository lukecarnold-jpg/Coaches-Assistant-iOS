import SwiftUI

struct APIKeyInputView: View {
    @Environment(\.dismiss) private var dismiss
    let provider: AIProvider
    let currentKey: String
    let onSave: (String) -> Void

    @State private var inputText = ""
    @State private var modelText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("\(provider.displayName) API Key", text: $inputText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("\(provider.displayName) API Key")
                } footer: {
                    Text("Your API key is stored securely in the Keychain on this device.")
                }

                Section {
                    TextField(provider.defaultModel, text: $modelText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Model (Optional)")
                } footer: {
                    Text("Leave blank to use the default, \(provider.defaultModel). Change this only if the provider retires that model.")
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        provider.modelOverride = modelText
                        onSave(inputText)
                        dismiss()
                    }
                }
            }
            .onAppear {
                inputText = currentKey
                modelText = provider.modelOverride
            }
        }
    }
}
