import SwiftUI

struct PromptSnippetsSettingsView: View {
    @ObservedObject private var store = PromptSnippetStore.shared
    @AppStorage(PromptSnippet.enabledKey) private var isEnabled = false
    @State private var trialCommand = "insert prompt code review"
    @State private var expandedID: UUID?

    var body: some View {
        Section {
            Toggle("Enable Prompt Snippets", isOn: $isEnabled)
            Text("Use your recording shortcut, say “insert prompt” followed by a name below, then stop. The saved prompt is pasted into your current field. Dictate your details next.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach($store.snippets) { $snippet in
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedID == snippet.id },
                    set: { expandedID = $0 ? snippet.id : nil }
                )) {
                    TextField("Spoken name", text: $snippet.name)
                    Text("Prompt text")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $snippet.text)
                        .font(.body)
                        .frame(minHeight: 130)
                        .accessibilityLabel("Prompt text for \(snippet.name)")
                    if let warning = validationMessage(for: snippet) {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Button("Delete Snippet", role: .destructive) {
                        store.snippets.removeAll { $0.id == snippet.id }
                    }
                } label: {
                    Label(snippet.name.isEmpty ? "New snippet" : "insert prompt \(snippet.name)",
                          systemImage: "text.badge.plus")
                }
            }

            Button("Add Snippet", systemImage: "plus") {
                let snippet = PromptSnippet(name: "", text: "")
                store.snippets.append(snippet)
                expandedID = snippet.id
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Try a command").font(.headline)
                TextField("insert prompt code review", text: $trialCommand)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Try a prompt snippet command")
                if let preview = PromptSnippet.expansion(for: trialCommand, snippets: store.snippets, enabled: true) {
                    Text(isEnabled ? "This will be pasted:" : "Preview — enable snippets to use this while recording:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(preview)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("No exact match. Your dictated words will be pasted as usual.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Prompt Snippets", systemImage: "sparkles")
        } footer: {
            Text("Saved on this Mac. Only a complete command expands; punctuation and capitalization are ignored. Snippets use your existing paste and Auto Send settings.")
        }
    }

    private func validationMessage(for snippet: PromptSnippet) -> String? {
        let name = PromptSnippet.normalized(snippet.name)
        if name.isEmpty { return "Add a spoken name to use this snippet." }
        if store.snippets.filter({ PromptSnippet.normalized($0.name) == name }).count > 1 {
            return "This name is duplicated. Give each snippet a unique spoken name."
        }
        if snippet.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add prompt text to use this snippet."
        }
        return nil
    }
}
