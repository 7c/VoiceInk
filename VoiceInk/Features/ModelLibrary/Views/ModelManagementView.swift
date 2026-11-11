import SwiftUI
struct ModelManagementView: View {
    @AppStorage("SelectedLanguage") private var language = "en-US"
    var body: some View {
        Form {
            Section("Offline transcription") {
                Label("Apple Speech", systemImage: "apple.logo")
                Text("Audio stays on this Mac. A missing language can be downloaded here on request: macOS fetches it from Apple, while VoiceInk itself stays offline.")
                    .foregroundStyle(.secondary)
                Picker("Language", selection: $language) {
                    ForEach(LanguageDictionary.appleNative.keys.sorted(), id: \.self) { code in
                        Text(LanguageDictionary.appleNative[code] ?? code).tag(code)
                    }
                }
                NativeAppleLanguageAssetControl(localeIdentifier: language)
            }
        }.formStyle(.grouped)
    }
}
