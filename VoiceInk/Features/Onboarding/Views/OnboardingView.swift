import SwiftUI
import AVFoundation
import AppKit
struct OnboardingView: View {
    @Binding var hasCompletedOnboardingV2: Bool
    @State private var microphoneAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @AppStorage("SelectedLanguage") private var language = "en-US"
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("VoiceInk Offline", systemImage: "mic.fill").font(.largeTitle.bold())
            Text("Record, transcribe, and keep your history on this Mac.").font(.title2)
            Text("This edition uses only built-in macOS frameworks. Network connections, cloud providers, updates, AI enhancement, and model downloads are removed.")
                .foregroundStyle(.secondary)
            Button(microphoneAllowed ? "Microphone access granted" : "Allow Microphone") {
                Task { microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio) }
            }.disabled(microphoneAllowed)
            Button("Open Accessibility Settings") {
                OfflineWorkspace.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            Text("Accessibility access enables the recording shortcut and pasting into other apps.").font(.caption)
            Picker("Transcription language", selection: $language) {
                ForEach(LanguageDictionary.appleNative.keys.sorted(), id: \.self) { code in
                    Text(LanguageDictionary.appleNative[code] ?? code).tag(code)
                }
            }
            NativeAppleLanguageAssetControl(localeIdentifier: language)
            Text("A language must already be installed by macOS. This app does not install missing assets.").font(.caption)
            Button("Open VoiceInk") {
                if ModeManager.shared.configurations.isEmpty {
                    StarterModeFactory.install(kinds: [.clean], provider: .voiceInkRefine, modelName: nil,
                        transcriptionModelName: "apple-speech", isRealtimeTranscriptionEnabled: false,
                        selectedLanguage: language)
                }
                hasCompletedOnboardingV2 = true
            }.buttonStyle(.borderedProminent)
        }.padding(48).frame(maxWidth: 720, alignment: .leading)
    }
}
