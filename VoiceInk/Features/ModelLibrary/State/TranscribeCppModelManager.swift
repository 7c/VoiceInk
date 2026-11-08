import Foundation
import Combine
@MainActor
class TranscribeCppModelManager: ObservableObject {
    static let shared = TranscribeCppModelManager()
    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?
    func isModelDownloaded(named: String) -> Bool { false }
    func isModelDownloaded(_ model: TranscribeCppModel) -> Bool { false }
}
class TranscribeCppTranscriptionService: CloudTranscriptionService {
    func loadModel(for model: TranscribeCppModel) async throws { throw OfflineMode.unavailable }
    func cleanup() {}
}
