import SwiftUI
struct ModelManagementView: View {
    @AppStorage("SelectedLanguage") private var language = "en-US"
    var body: some View {
        Form {
            Section("Offline transcription") {
                Label("Apple Speech", systemImage: "apple.logo")
                Text("Audio stays on this Mac. Only language assets already installed by macOS can be used. This app never downloads models.")
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
