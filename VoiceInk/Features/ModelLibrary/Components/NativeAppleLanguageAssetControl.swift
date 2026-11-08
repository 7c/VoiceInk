import SwiftUI
struct NativeAppleLanguageAssetControl: View {
    let localeIdentifier: String
    var isVisible = true
    var startsDownloadAutomatically = false
    @State private var state: NativeAppleSpeechAssetState = .checking
    var body: some View {
        if isVisible {
            Text(state == .checking ? "Checking installed language…" :
                 state == .downloaded ? "Installed — ready for offline use" : "Language not installed; downloads are disabled")
                .foregroundStyle(.secondary)
                .task(id: localeIdentifier) { state = await NativeAppleSpeechAssetManager.assetState(for: localeIdentifier) }
        }
    }
}
