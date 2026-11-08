import Foundation
import Combine
@MainActor
class FluidAudioModelManager: ObservableObject {
    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?
    func isFluidAudioModelDownloaded(named: String) -> Bool { false }
    func isFluidAudioModelDownloaded(_ model: FluidAudioModel) -> Bool { false }
    nonisolated static func isParakeetUnifiedModel(named: String) -> Bool { false }
    nonisolated static func isNemotronModel(named: String) -> Bool { false }
    nonisolated static func requiresRealtime(named: String) -> Bool { false }
}
class FluidAudioTranscriptionService: CloudTranscriptionService {
    func loadModel(for model: FluidAudioModel) async throws { throw OfflineMode.unavailable }
    func cleanup() async {}
    func prepareModel(_ model: FluidAudioModel) async throws { throw OfflineMode.unavailable }
}
