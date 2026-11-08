import Foundation
import SwiftData
import Combine
@MainActor
class ModelPrewarmService: ObservableObject {
    init(transcriptionModelManager: TranscriptionModelManager, whisperModelManager: WhisperModelManager,
         modelContext: ModelContext, fluidAudioService: FluidAudioTranscriptionService) {}
}
