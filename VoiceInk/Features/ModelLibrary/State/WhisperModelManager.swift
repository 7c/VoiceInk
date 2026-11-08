import Foundation
import SwiftUI
struct WhisperModelFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var coreMLEncoderURL: URL?
    var isCoreMLDownloaded: Bool { false }
}
@MainActor
class WhisperModelManager: ObservableObject, WhisperModelProvider {
    @Published var availableModels: [WhisperModelFile] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var whisperContext: WhisperContext?
    @Published var isModelLoaded = true
    @Published var loadedWhisperModel: WhisperModelFile?
    @Published var isModelLoading = false
    let modelsDirectory: URL
    let whisperPrompt = WhisperPrompt()
    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?
    init(modelsDirectory: URL) { self.modelsDirectory = modelsDirectory }
    func createModelsDirectoryIfNeeded() {}
    func loadAvailableModels() {}
    func loadModel(_ model: WhisperModelFile) async throws { throw OfflineMode.unavailable }
    func unloadModel() { whisperContext = nil; loadedWhisperModel = nil }
    func cleanupResources() async { unloadModel() }
    func clearDownloadedModels() async {}
}
