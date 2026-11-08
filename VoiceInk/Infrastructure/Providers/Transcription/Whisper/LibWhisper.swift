import Foundation
actor WhisperContext {
    static func createContext(path: String) async throws -> WhisperContext { throw OfflineMode.unavailable }
    func transcribe(samples: [Float], request: TranscriptionRequestContext) throws -> String { throw OfflineMode.unavailable }
    func releaseResources() {}
    func setPrompt(_ prompt: String?) {}
    func setLanguage(_ language: String?) {}
}
