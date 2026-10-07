import Foundation

/// The AI providers the Training drill generator can use. Each has its own API key,
/// its own request/response shape (see `DrillGenerationService.swift`), and its own
/// default model — picked for low cost on a lightweight "generate 5 drills" task.
enum AIProvider: String, CaseIterable, Identifiable {
    case gemini
    case claude
    case openAI
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .claude:  return "Anthropic Claude"
        case .openAI:  return "OpenAI ChatGPT"
        case .custom:  return "Other (Custom)"
        }
    }

    /// Keychain account name for this provider's key — distinct per provider so all
    /// three can be stored at once under one Keychain service.
    var keychainAccount: String { "aiAPIKey.\(rawValue)" }

    /// Built-in model per provider, picked for low cost on a short templated task.
    /// Coaches can override it in Settings if a provider retires a model name.
    var defaultModel: String {
        switch self {
        case .gemini: return "gemini-3.8-flash"
        case .claude: return "claude-haiku-4-5-20251001"
        case .openAI: return "gpt-5.6-luna"
        case .custom: return ""
        }
    }

    private var modelOverrideKey: String { "aiModelOverride.\(rawValue)" }

    /// User-set model name, or empty to use `defaultModel`.
    var modelOverride: String {
        get { UserDefaults.standard.string(forKey: modelOverrideKey) ?? "" }
        nonmutating set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: modelOverrideKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: modelOverrideKey)
            }
        }
    }

    var effectiveModel: String {
        modelOverride.isEmpty ? defaultModel : modelOverride
    }
}
