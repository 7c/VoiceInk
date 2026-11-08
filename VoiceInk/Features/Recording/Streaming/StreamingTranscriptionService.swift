import Foundation
enum StreamingStopResult { case finalized(text: String); case requiresBatchFallback }
@MainActor
class StreamingTranscriptionService {
    var isActive: Bool { false }
    init(fluidAudioService: FluidAudioTranscriptionService? = nil, onPartialTranscript: ((String) -> Void)? = nil) {}
    func startStreaming(model: any TranscriptionModel, context: TranscriptionRequestContext) async throws { throw OfflineMode.unavailable }
    nonisolated func sendAudioChunk(_ data: Data) {}
    func stopAndFinalize() async throws -> StreamingStopResult { .requiresBatchFallback }
    func cancel() {}
}
