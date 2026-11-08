import Foundation
import Combine
enum AIProvider: String, CaseIterable, Sendable {
    case cerebras = "Cerebras"
    case groq = "Groq"
    case gemini = "Gemini"
    case anthropic = "Anthropic"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    case mistral = "Mistral"
    case elevenLabs = "ElevenLabs"
    case deepgram = "Deepgram"
    case soniox = "Soniox"
    case speechmatics = "Speechmatics"
    case assemblyAI = "AssemblyAI"
    case voiceInkRefine = "VoiceInk Refine"
    case ollama = "Ollama"
    case localCLI = "Local CLI"
    case custom = "Custom"


    var baseURL: String { "" }
    var defaultModel: String { "" }
    var availableModels: [String] { [] }
    var requiresAPIKey: Bool { false }
    var supportsEnhancement: Bool { false }
    var supportsCustomModelID: Bool { false }
}
struct OllamaModel { let name: String }
struct OllamaRefreshResult { let models: [OllamaModel]; let errorMessage: String? }
class AIService: ObservableObject {
    @Published var apiKey = ""
    @Published var isAPIKeyValid = false
    @Published var customBaseURL = ""
    @Published var customModel = ""
    @Published var selectedProvider: AIProvider = .voiceInkRefine
    let voiceInkRefineService = VoiceInkRefineService.shared
    let isOllamaRefreshing = false
    var connectedProviders: [AIProvider] { [] }
    var currentModel: String { "" }
    var availableModels: [String] { [] }
    var localCLICommandTemplate: String { "" }
    var localCLITemplateSelection: LocalCLITemplate { .pi }
    var localCLITimeoutSeconds: Double { 45 }
    func selectedModel(for provider: AIProvider) -> String { "" }
    func customModelID(for provider: AIProvider) -> String { "" }
    func availableModels(for provider: AIProvider) -> [String] { [] }
    func selectModel(_ model: String) {}
    func selectModel(_ model: String, for provider: AIProvider) {}
    func saveAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) { completion(false, OfflineMode.unavailable.localizedDescription) }
    func verifyAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) { completion(false, OfflineMode.unavailable.localizedDescription) }
    func verifyAPIKey(_ key: String, for provider: AIProvider, model: String? = nil) async -> (isValid: Bool, errorMessage: String?) { (false, OfflineMode.unavailable.localizedDescription) }
    func clearAPIKey() {}
    func checkOllamaConnection(completion: @escaping (Bool) -> Void) { completion(false) }
    func refreshOllamaAvailabilityInBackground() {}
    func refreshOllamaConnectionAndModels() async -> [OllamaModel] { [] }
    func refreshOllamaAvailability() async -> OllamaRefreshResult { .init(models: [], errorMessage: OfflineMode.unavailable.localizedDescription) }
    func fetchOpenRouterModelsIfNeededForMigration() async {}
    func fetchOpenRouterModels() async {}
    func updateOllamaBaseURL(_ url: String) {}
    func updateSelectedOllamaModel(_ model: String) {}
    func loadLocalCLITemplate(_ template: LocalCLITemplate) {}
    func updateLocalCLICommandTemplate(_ command: String) {}
    func updateLocalCLITimeoutSeconds(_ timeout: Double) {}
}
