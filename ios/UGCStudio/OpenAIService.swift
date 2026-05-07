import Foundation

nonisolated enum OpenAIError: Error, LocalizedError {
    case missingToken
    case badResponse(Int, String?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingToken: return "OpenAI key missing. Add it in Settings."
        case .badResponse(let code, let msg): return "OpenAI HTTP \(code)\(msg.map { ": \($0)" } ?? "")."
        case .decoding: return "Could not parse OpenAI response."
        }
    }
}

@MainActor
@Observable
final class OpenAIService {
    static let shared = OpenAIService()

    var lastError: String?
    var inflight: Bool = false

    // Cheap and good enough for short script copy.
    private let model = "gpt-4o-mini"
    private let session: URLSession = .shared
    private var token: String { TokenStore.resolvedOpenAIToken }

    var isConfigured: Bool { !token.isEmpty }

    func generateScript(
        brand: String,
        campaignTitle: String,
        brief: String
    ) async throws -> ScriptDraft {
        guard !token.isEmpty else { throw OpenAIError.missingToken }
        inflight = true
        defer { inflight = false }

        let userPrompt = """
        Brand: \(brand.isEmpty ? "(unspecified)" : brand)
        Campaign: \(campaignTitle.isEmpty ? "(unspecified)" : campaignTitle)
        Creative brief / direction: \(brief.isEmpty ? "punchy creator-style endorsement, 30-45 sec" : brief)

        Write a short-form UGC ad script for this brand. Target: TikTok / Instagram Reels / YouTube Shorts. Native creator voice, no corporate marketing speak. Specific, sensory, concrete. No emojis.

        Return STRICT JSON ONLY with these keys:
        - title: 2-5 word working name for this script
        - hook: the first line said on camera (under 14 words, attention-grabbing, no questions to the camera unless great)
        - body: a multi-line script body. Use newlines to separate beats. 4-7 short beats. Format each beat as "BEAT: line of dialogue or direction".
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You write punchy short-form creator ad scripts for paid UGC. Output strict JSON only — no preamble, no markdown."],
                ["role": "user", "content": userPrompt],
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.8,
        ]

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 45

        let (data, response) = try await session.data(for: req)
        let http = response as? HTTPURLResponse
        let code = http?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let text = String(data: data, encoding: .utf8)?.prefix(240).description
            throw OpenAIError.badResponse(code, text)
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.decoding
        }
        let rawParsed = try? JSONSerialization.jsonObject(with: Data(content.utf8))
        guard let parsed = rawParsed as? [String: Any] else {
            throw OpenAIError.decoding
        }

        return ScriptDraft(
            id: UUID(),
            title: (parsed["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Generated script",
            hook: (parsed["hook"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            body: (parsed["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            createdAt: Date()
        )
    }

    /// Generate three variations at once (single call, ~1500 tokens worst case).
    func generateScriptBatch(
        brand: String,
        campaignTitle: String,
        brief: String
    ) async throws -> [ScriptDraft] {
        guard !token.isEmpty else { throw OpenAIError.missingToken }
        inflight = true
        defer { inflight = false }

        let userPrompt = """
        Brand: \(brand.isEmpty ? "(unspecified)" : brand)
        Campaign: \(campaignTitle.isEmpty ? "(unspecified)" : campaignTitle)
        Creative direction: \(brief.isEmpty ? "punchy creator-style endorsement, 30-45 sec" : brief)

        Write THREE distinct UGC ad script options for short-form video. Each should take a different angle (e.g. problem-solution, surprise demo, day-in-the-life, hot-take, before/after). Native creator voice. No emojis. No corporate copy.

        Return STRICT JSON: {"scripts": [{"title", "hook", "body"}, ...]}.
        - title: 2-5 word working name
        - hook: first on-camera line, under 14 words
        - body: 4-7 beats, newline-separated, each formatted "BEAT: ...".
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You write punchy short-form creator ad scripts. Output strict JSON only."],
                ["role": "user", "content": userPrompt],
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.9,
        ]

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await session.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let text = String(data: data, encoding: .utf8)?.prefix(240).description
            throw OpenAIError.badResponse(code, text)
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.decoding
        }
        let rawParsed = try? JSONSerialization.jsonObject(with: Data(content.utf8))
        guard let parsed = rawParsed as? [String: Any],
              let arr = parsed["scripts"] as? [[String: Any]] else {
            throw OpenAIError.decoding
        }

        return arr.map { entry in
            ScriptDraft(
                id: UUID(),
                title: (entry["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Script",
                hook: (entry["hook"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                body: (entry["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                createdAt: Date()
            )
        }
    }
}
