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
    func generateDrills(ageGroup: String, apiKey: String, sport: Sport) async throws -> [String]
}

extension DrillGenerating {
    /// Basketball's call site (`TrainingView`) omits `sport` entirely — this
    /// default keeps that call byte-identical rather than requiring an edit
    /// there just to satisfy a parameter it doesn't care about.
    func generateDrills(ageGroup: String, apiKey: String) async throws -> [String] {
        try await generateDrills(ageGroup: ageGroup, apiKey: apiKey, sport: .basketball)
    }
}

extension AIProvider {
    var drillService: DrillGenerating {
        switch self {
        case .gemini: return GeminiDrillService(model: effectiveModel)
        case .claude: return ClaudeDrillService(model: effectiveModel)
        case .openAI: return OpenAIDrillService(model: effectiveModel)
        case .custom: return CustomDrillService(baseURL: CustomProviderSettings.shared.baseURL, model: CustomProviderSettings.shared.model)
        }
    }
}

/// Shared session with a bounded timeout, so a stalled provider surfaces an error
/// instead of leaving the Training screen spinning indefinitely.
enum DrillHTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()
}

nonisolated func drillPrompt(ageGroup: String, sport: Sport) -> String {
    "Generate 5 \(sport.rules.drillNoun) practice drills suitable for \(ageGroup) players. For each drill, provide a short name followed by a 1-2 sentence description. Format as a numbered list with just the drill name and description, no extra headers."
}

/// Numbered-list parsing shared by every provider — the request/response plumbing
/// differs per API, but the prompted output shape ("1. Name — description") is the same.
nonisolated func parseDrillList(from text: String) -> [String] {
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
    var model: String = AIProvider.gemini.defaultModel

    func generateDrills(ageGroup: String, apiKey: String, sport: Sport) async throws -> [String] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw DrillGenerationError.missingConfiguration("The Gemini model name isn't valid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Sent as a header rather than a `?key=` query parameter, which would end up
        // in proxy and server access logs.
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["contents": [["parts": [["text": drillPrompt(ageGroup: ageGroup, sport: sport)]]]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await DrillHTTP.session.data(for: request)
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
    var model: String = AIProvider.claude.defaultModel

    func generateDrills(ageGroup: String, apiKey: String, sport: Sport) async throws -> [String] {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": drillPrompt(ageGroup: ageGroup, sport: sport)]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await DrillHTTP.session.data(for: request)
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
    var model: String = AIProvider.openAI.defaultModel

    func generateDrills(ageGroup: String, apiKey: String, sport: Sport) async throws -> [String] {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": model, "input": drillPrompt(ageGroup: ageGroup, sport: sport)]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await DrillHTTP.session.data(for: request)
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

    func generateDrills(ageGroup: String, apiKey: String, sport: Sport) async throws -> [String] {
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
            "messages": [["role": "user", "content": drillPrompt(ageGroup: ageGroup, sport: sport)]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await DrillHTTP.session.data(for: request)
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
