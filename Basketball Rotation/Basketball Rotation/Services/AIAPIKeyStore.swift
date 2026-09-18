import Foundation
import SwiftUI

/// Shared, Keychain-backed holder for each AI provider's API key.
/// Replaces a prior single-provider (Gemini-only) store; on first access this migrates
/// any key saved under that old store across to the Gemini slot here.
@Observable
final class AIAPIKeyStore {
    static let shared = AIAPIKeyStore()

    private static let service = "com.basketballrotation.aiAPIKey"
    private static let legacyGeminiService = "com.basketballrotation.geminiAPIKey"
    private static let legacyGeminiAccount = "geminiAPIKey"

    private var keys: [AIProvider: String]

    func apiKey(for provider: AIProvider) -> String {
        keys[provider] ?? ""
    }

    func setAPIKey(_ value: String, for provider: AIProvider) {
        keys[provider] = value
        KeychainHelper.save(value, account: provider.keychainAccount, service: Self.service)
    }

    /// Whether this provider is ready to use. The custom provider doesn't require a key
    /// (many self-hosted servers have none) but does require a base URL and model name.
    func isConfigured(_ provider: AIProvider) -> Bool {
        if provider == .custom {
            return CustomProviderSettings.shared.isConfigured
        }
        return !apiKey(for: provider).isEmpty
    }

    private init() {
        keys = [:]
        for provider in AIProvider.allCases {
            keys[provider] = KeychainHelper.read(account: provider.keychainAccount, service: Self.service)
        }

        if keys[.gemini]?.isEmpty ?? true {
            let legacy = KeychainHelper.read(account: Self.legacyGeminiAccount, service: Self.legacyGeminiService)
            if !legacy.isEmpty {
                setAPIKey(legacy, for: .gemini)
            }
        }
    }
}
