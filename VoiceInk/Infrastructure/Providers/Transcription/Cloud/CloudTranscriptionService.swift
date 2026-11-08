import Foundation
class CloudTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String {
        throw OfflineMode.unavailable
    }
}
enum CloudTranscriptionError: Error { case unsupportedProvider }
