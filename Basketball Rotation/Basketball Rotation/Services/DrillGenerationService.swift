import Foundation

enum DrillGenerationError: LocalizedError {
    case apiError(String)
    case unparseableResponse
    case missingConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return "API error: \(message)"
        case .unparseableResponse: return "Could not parse response."
        case .missingConfiguration(let message): return message
        }
    }
}

protocol DrillGenerating {
    func generateDrills(ageGroup: String, apiKey: String) async throws -> [String]
}

extension AIProvider {
    var drillService: DrillGenerating {
        switch self {
        case .gemini: return GeminiDrillService()
        case .claude: return ClaudeDrillService()
        case .openAI: return OpenAIDrillService()
        case .custom: return CustomDrillService(baseURL: CustomProviderSettings.shared.baseURL, model: CustomProviderSettings.shared.model)
        }
    }
}

private func drillPrompt(ageGroup: String) -> String {
    "Generate 5 basketball practice drills suitable for \(ageGroup) players. For each drill, provide a short name followed by a 1-2 sentence description. Format as a numbered list with just the drill name and description, no extra headers."
}

/// Numbered-list parsing shared by every provider — the request/response plumbing
/// differs per API, but the prompted output shape ("1. Name — description") is the same.
func parseDrillList(from text: String) -> [String] {
    let lines = text.components(separatedBy: "\n")
    var result: [String] = []
    var currentDrill = ""

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        let isNewDrill = trimmed.first?.isNumber == true && trimmed.contains(".")
        if isNewDrill {
            if !currentDrill.isEmpty {
                result.append(currentDrill.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            currentDrill = trimmed
        } else if !currentDrill.isEmpty {
            // Continuation of a wrapped line. Text before the first numbered item
            // (e.g. a model prefacing with "Here are your drills:") is dropped rather
            // than turned into a bogus extra "drill".
            currentDrill += " " + trimmed
        }
    }
    if !currentDrill.isEmpty {
        result.append(currentDrill.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return result.prefix(5).map { drill in
        drill.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
    }
}

private func apiErrorMessage(from data: Data) -> String {
    String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? "Unknown error"
}

// MARK: - Gemini

struct GeminiDrillService: DrillGenerating {
    func generateDrills(ageGroup: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["contents": [["parts": [["text": drillPrompt(ageGroup: ageGroup)]]]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DrillGenerationError.apiError(apiErrorMessage(from: data))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw DrillGenerationError.unparseableResponse
        }
        return parseDrillList(from: text)
    }
}

// MARK: - Claude

struct ClaudeDrillService: DrillGenerating {
    /// Haiku 4.5 — current fast/cheap tier, plenty for a short templated drill list.
    private let model = "claude-haiku-4-5-20251001"

    func generateDrills(ageGroup: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": drillPrompt(ageGroup: ageGroup)]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DrillGenerationError.apiError(apiErrorMessage(from: data))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw DrillGenerationError.unparseableResponse
        }
        return parseDrillList(from: text)
    }
}

// MARK: - OpenAI

struct OpenAIDrillService: DrillGenerating {
    /// GPT-5.6 Luna — current cheapest/fastest tier via the Responses API.
    private let model = "gpt-5.6-luna"

    func generateDrills(ageGroup: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": model, "input": drillPrompt(ageGroup: ageGroup)]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DrillGenerationError.apiError(apiErrorMessage(from: data))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["output_text"] as? String else {
            throw DrillGenerationError.unparseableResponse
        }
        return parseDrillList(from: text)
    }
}

// MARK: - Custom (OpenAI-compatible)

/// Talks to any server that speaks the OpenAI-compatible Chat Completions API — the
/// shape shared by Ollama, LM Studio, OpenRouter, Groq, Together.ai, and most other
/// self-hosted or third-party LLM gateways. `baseURL` should be the API root
/// (e.g. "http://localhost:11434/v1"); "/chat/completions" is appended to it.
struct CustomDrillService: DrillGenerating {
    let baseURL: String
    let model: String

    func generateDrills(ageGroup: String, apiKey: String) async throws -> [String] {
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty, !trimmedModel.isEmpty else {
            throw DrillGenerationError.missingConfiguration("Set a Base URL and Model name for the custom provider in Settings.")
        }
        let path = trimmedBase.hasSuffix("/") ? "\(trimmedBase)chat/completions" : "\(trimmedBase)/chat/completions"
        guard let url = URL(string: path) else {
            throw DrillGenerationError.missingConfiguration("The custom provider Base URL isn't a valid URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "model": trimmedModel,
            "messages": [["role": "user", "content": drillPrompt(ageGroup: ageGroup)]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DrillGenerationError.apiError(apiErrorMessage(from: data))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw DrillGenerationError.unparseableResponse
        }
        return parseDrillList(from: text)
    }
}
