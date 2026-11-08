import Combine
import Foundation

@MainActor
final class PromptSnippetStore: ObservableObject {
    static let shared = PromptSnippetStore()
    @Published var snippets: [PromptSnippet] {
        didSet {
            if let data = try? JSONEncoder().encode(snippets) {
                UserDefaults.standard.set(data, forKey: PromptSnippet.storageKey)
            }
        }
    }

    private init() { snippets = PromptSnippet.load(from: .standard) }

    func expansion(for transcript: String) -> String? {
        PromptSnippet.expansion(for: transcript, snippets: snippets,
                                enabled: UserDefaults.standard.bool(forKey: PromptSnippet.enabledKey))
    }
}
