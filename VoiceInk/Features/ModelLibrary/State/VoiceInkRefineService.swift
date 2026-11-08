import Foundation
import Combine
enum VoiceInkRefineAvailability: Equatable { case available, unsupportedArchitecture, insufficientMemory }
@MainActor
final class VoiceInkRefineService: ObservableObject {
    static let shared = VoiceInkRefineService()
    static let providerName = "VoiceInk Refine"
    static let modelName = "VoiceInk Refine V1"
    let isDownloaded = false
    let isDownloading = false
    let isAvailableInModes = false
    let unavailableDescription: String? = "AI enhancement is not included in the offline edition."
    func enhance(transcript: String, vocabulary: RecordingVocabulary) async throws -> String { throw OfflineMode.unavailable }
    func unloadPreparedModelIfNeeded() async {}
    func keepPreparedModelWarmForRecording() async {}
    func prepareForRecording() async {}
}
