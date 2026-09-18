import SwiftUI

struct CustomProviderConfigView: View {
    @Environment(\.dismiss) private var dismiss
    let currentKey: String
    let onSaveKey: (String) -> Void

    @Bindable private var settings = CustomProviderSettings.shared
    @State private var inputKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Base URL", text: $settings.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Model Name", text: $settings.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Custom Provider")
                } footer: {
                    Text("Any server that speaks the OpenAI-compatible Chat Completions API — e.g. Ollama, LM Studio, OpenRouter, or Groq. Base URL should be the API root, such as http://localhost:11434/v1.")
                }

                Section {
                    SecureField("API Key (optional)", text: $inputKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("Leave blank if your server doesn't require one. Stored securely in the Keychain on this device.")
                }
            }
            .navigationTitle("Custom Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSaveKey(inputKey)
                        dismiss()
                    }
                }
            }
            .onAppear { inputKey = currentKey }
        }
    }
}
