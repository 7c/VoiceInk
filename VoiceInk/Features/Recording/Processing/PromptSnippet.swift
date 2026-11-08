import Foundation

struct PromptSnippet: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var text: String

    static let enabledKey = "PromptSnippetsEnabled"
    static let storageKey = "PromptSnippetsLibrary"

    static let starters = [
        PromptSnippet(name: "code review", text: """
        Review the code below for correctness, edge cases, security, and maintainability.

        Prioritize concrete bugs over style preferences. For each finding, explain the impact and suggest a minimal fix. If something depends on missing context, state your assumption. Finish with the most valuable tests to add.

        Code:
        """),
        PromptSnippet(name: "make a plan", text: """
        Turn the goal below into a practical implementation plan.

        Start with the intended outcome. Break the work into small, ordered steps, identify dependencies and risks, and define how we will verify success. Ask questions only where an answer would materially change the plan.

        Goal:
        """),
        PromptSnippet(name: "clear writing", text: """
        Rewrite the text below for clarity and concision. Preserve the meaning, facts, and tone. Use plain language and active voice. Do not invent details. Return only the revised text.

        Text:
        """),
    ]

    /// Only a complete command expands. Ordinary sentences, unknown names, and
    /// ambiguous duplicate names pass through unchanged. No recursive expansion.
    static func expansion(for transcript: String, snippets: [Self], enabled: Bool) -> String? {
        guard enabled else { return nil }
        let command = normalized(transcript)
        let prefix = "insert prompt "
        guard command.hasPrefix(prefix) else { return nil }
        let name = String(command.dropFirst(prefix.count))
        guard !name.isEmpty else { return nil }
        let matches = snippets.filter { normalized($0.name) == name }
        guard matches.count == 1, let snippet = matches.first,
            !snippet.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return snippet.text
    }

    static func normalized(_ text: String) -> String {
        text.lowercased(with: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func load(from defaults: UserDefaults) -> [Self] {
        guard let data = defaults.data(forKey: storageKey) else { return starters }
        return (try? JSONDecoder().decode([Self].self, from: data)) ?? []
    }
}
