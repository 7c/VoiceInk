// Compiles the production Apple Speech service in isolation, using only Apple frameworks.
import Foundation
import Speech
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
            throw NSError(domain: "SmokeTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Requires already installed en-US assets. This test never downloads a language."])
        }
        let text = try await service.transcribe(audioURL: audio, model: NativeAppleModel(), context: .init(language: "en-US"))
        print("Transcript: \(text)")
        guard text.lowercased().contains("offline"), text.lowercased().contains("test") else {
            throw NSError(domain: "SmokeTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected the local spoken fixture to include offline and test."])
        }
        guard await NativeAppleSpeechAssetManager.assetContext(for: "zz-ZZ") == nil else {
            throw NSError(domain: "SmokeTest", code: 3)
        }
        let installed = Set(await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) })
        // An unknown language must be reported as unsupported, never as downloadable or as a failed download.
        guard await NativeAppleSpeechAssetManager.assetState(for: "zz-ZZ") == .notSupported else {
            throw NSError(domain: "SmokeTest", code: 4, userInfo: [NSLocalizedDescriptionKey: "An unsupported language must report notSupported."])
        }
        guard await NativeAppleSpeechAssetManager.installAsset(for: "zz-ZZ") == .notSupported else {
            throw NSError(domain: "SmokeTest", code: 5, userInfo: [NSLocalizedDescriptionKey: "Installing an unsupported language must report notSupported."])
        }
        // A supported language that is not installed must be offered for download, not hidden as unsupported.
        let missing = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }.sorted().first { identifier in
            !installed.contains(identifier)
        }
        guard let missing else {
            print("PASS: native transcription works and unsupported languages are rejected. Every supported language is installed, so missing-language handling was not exercised.")
            return
        }
        let missingState = await NativeAppleSpeechAssetManager.assetState(for: missing)
        guard missingState == .needsDownload || missingState == .downloading else {
            throw NSError(domain: "SmokeTest", code: 6, userInfo: [NSLocalizedDescriptionKey: "\(missing) is supported but not installed, yet reported \(missingState) instead of needsDownload."])
        }
        // Dictating in a missing language must ask for a download, never start one.
        do {
            _ = try await service.transcribe(audioURL: audio, model: NativeAppleModel(), context: .init(language: missing))
            throw NSError(domain: "SmokeTest", code: 7, userInfo: [NSLocalizedDescriptionKey: "Transcribing in missing language \(missing) must fail."])
        } catch NativeAppleTranscriptionService.ServiceError.assetDownloadRequired {
            // Expected.
        }
        let installedAfterwards = Set(await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) })
        guard installedAfterwards == installed else {
            throw NSError(domain: "SmokeTest", code: 8, userInfo: [NSLocalizedDescriptionKey: "Transcribing in \(missing) changed the installed languages."])
        }
        print("PASS: native transcription works; unsupported languages are rejected; missing \(missing) is offered for download and dictating in it never starts one")
    }
}
