import Foundation
import SwiftUI

/// Non-secret configuration for the "Other" custom provider. Assumed to speak the
/// OpenAI-compatible Chat Completions shape — the de facto standard for self-hosted
/// and third-party gateways (Ollama, LM Studio, OpenRouter, Groq, Together.ai, etc.).
/// Stored in UserDefaults rather than the Keychain since neither field is a credential.
@Observable
final class CustomProviderSettings {
    static let shared = CustomProviderSettings()

    private static let baseURLKey = "customProviderBaseURL"
    private static let modelKey = "customProviderModel"

    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Self.baseURLKey) }
    }
    var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Self.modelKey) }
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private init() {
        baseURL = UserDefaults.standard.string(forKey: Self.baseURLKey) ?? ""
        model = UserDefaults.standard.string(forKey: Self.modelKey) ?? ""
    }
}
