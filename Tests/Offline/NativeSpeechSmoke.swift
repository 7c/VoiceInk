// Compiles the production Apple Speech service in isolation, using only Apple frameworks.
import Foundation
protocol TranscriptionModel {}
struct NativeAppleModel: TranscriptionModel {}
struct TranscriptionRequestContext { let language: String? }
protocol TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String
}
enum LanguageDictionary { static let appleNative = ["en-US": "English (US)"] }
@main struct NativeSpeechSmoke {
    static func main() async throws {
        let service = NativeAppleTranscriptionService()
        let audio = URL(fileURLWithPath: CommandLine.arguments[1])
        guard await NativeAppleSpeechAssetManager.assetState(for: "en-US") == .downloaded else {
            throw NSError(domain: "SmokeTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Requires already installed en-US assets. No downloads are attempted."])
        }
        let text = try await service.transcribe(audioURL: audio, model: NativeAppleModel(), context: .init(language: "en-US"))
        print("Transcript: \(text)")
        guard text.lowercased().contains("offline"), text.lowercased().contains("test") else {
            throw NSError(domain: "SmokeTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected the local spoken fixture to include offline and test."])
        }
        guard await NativeAppleSpeechAssetManager.assetContext(for: "zz-ZZ") == nil else {
            throw NSError(domain: "SmokeTest", code: 3)
        }
        if case .failed = await NativeAppleSpeechAssetManager.installAsset(for: "zz-ZZ") {
            print("PASS: native transcription works; missing languages cannot trigger a download")
        } else { throw NSError(domain: "SmokeTest", code: 4) }
    }
}
