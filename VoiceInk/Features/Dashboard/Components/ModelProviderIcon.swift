import SwiftUI
struct ModelProviderIcon: View {
    let modelName: String
    let kind: ModelInsightKind
    var size: CGFloat = 24
    var body: some View {
        Image(systemName: modelName.localizedCaseInsensitiveContains("apple") ? "apple.logo" : "waveform")
            .frame(width: size, height: size).help(modelName)
    }
}
