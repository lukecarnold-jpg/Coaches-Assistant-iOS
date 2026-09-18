import SwiftUI

struct APIKeyInputView: View {
    @Environment(\.dismiss) private var dismiss
    let provider: AIProvider
    let currentKey: String
    let onSave: (String) -> Void

    @State private var inputText = ""

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
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(inputText)
                        dismiss()
                    }
                }
            }
            .onAppear { inputText = currentKey }
        }
    }
}
