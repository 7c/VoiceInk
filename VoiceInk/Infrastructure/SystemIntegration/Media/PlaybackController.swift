import Foundation
import Combine
@MainActor
class PlaybackController: ObservableObject {
    static let shared = PlaybackController()
    @Published var isPauseMediaEnabled = false
    func beginRecordingSession() -> UUID { UUID() }
    func pauseMedia(sessionID: UUID) async {}
    func resumeMedia(sessionID: UUID) async {}
}
