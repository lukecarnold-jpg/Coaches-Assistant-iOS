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
}
