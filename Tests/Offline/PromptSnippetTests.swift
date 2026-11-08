import Foundation

@main
struct PromptSnippetTests {
    static func main() throws {
        let snippet = PromptSnippet(name: "code review", text: "Review this:\n\n`code` {exactly}")
        func expand(_ text: String, enabled: Bool = true, snippets: [PromptSnippet]? = nil) -> String? {
            PromptSnippet.expansion(for: text, snippets: snippets ?? [snippet], enabled: enabled)
        }
        assert(expand("Insert prompt code review.") == snippet.text)
        assert(expand("INSERT PROMPT: code review!") == snippet.text)
        assert(expand(" insert  prompt\ncode review ") == snippet.text)
        assert(expand("insert prompt code review", enabled: false) == nil)
        assert(expand("Please insert prompt code review") == nil)
        assert(expand("insert prompt code review and explain this") == nil)
        assert(expand("insert prompt unknown") == nil)
        assert(expand("insert prompt") == nil)
        assert(expand("We discussed the phrase insert prompt code review.") == nil)
        assert(expand("insert prompt code reviews") == nil)
        assert(expand("insert prompt code review", snippets: []) == nil)
        let duplicate = PromptSnippet(name: "CODE-REVIEW", text: "Other content")
        assert(expand("insert prompt code review", snippets: [snippet, duplicate]) == nil)
        assert(expand("insert prompt empty", snippets: [.init(name: "empty", text: " \n ")]) == nil)
        assert(expand("insert prompt café", snippets: [.init(name: "café", text: "Résumé")]) == "Résumé")
        let recursive = PromptSnippet(name: "code review", text: "insert prompt make a plan")
        assert(expand("insert prompt code review", snippets: [recursive]) == recursive.text)

        let suiteName = "VoiceInk.PromptSnippetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        assert(!defaults.bool(forKey: PromptSnippet.enabledKey))
        assert(PromptSnippet.load(from: defaults) == PromptSnippet.starters)
        defaults.set(try JSONEncoder().encode([snippet]), forKey: PromptSnippet.storageKey)
        assert(PromptSnippet.load(from: defaults) == [snippet])
        defaults.set(try JSONEncoder().encode([PromptSnippet]()), forKey: PromptSnippet.storageKey)
        assert(PromptSnippet.load(from: defaults).isEmpty, "Deleted starters must not return")
        defaults.set(Data("invalid".utf8), forKey: PromptSnippet.storageKey)
        assert(PromptSnippet.load(from: defaults).isEmpty)
        print("PASS: prompt commands, literal content, opt-in behavior, ambiguity, and persistence (20 checks)")
    }
}
