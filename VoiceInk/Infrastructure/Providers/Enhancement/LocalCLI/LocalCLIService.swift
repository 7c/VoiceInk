import Foundation

enum LocalCLITemplate: String, CaseIterable, Identifiable {
    case pi
    case claude
    case codex
    case copilot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pi: return "Pi"
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .copilot: return "Copilot"
        }
    }

    var commandTemplate: String { "" }
}

final class LocalCLIService {
    static let commandTemplateKey = "localCLICommandTemplate"
    static let selectedTemplateKey = "localCLISelectedTemplate"
    static let timeoutSecondsKey = "localCLITimeoutSeconds"
    static let defaultTimeoutSeconds: Double = 45

    var commandTemplate: String {
        didSet {
            UserDefaults.standard.set(commandTemplate, forKey: Self.commandTemplateKey)
        }
    }

    var selectedTemplate: LocalCLITemplate {
        didSet {
            UserDefaults.standard.set(selectedTemplate.rawValue, forKey: Self.selectedTemplateKey)
        }
    }

    var timeoutSeconds: Double {
        didSet {
            let clamped = max(5, timeoutSeconds)
            if clamped != timeoutSeconds {
                timeoutSeconds = clamped
                return
            }
            UserDefaults.standard.set(timeoutSeconds, forKey: Self.timeoutSecondsKey)
        }
    }

    var isConfigured: Bool {
        !commandTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        let savedTemplateRaw = UserDefaults.standard.string(forKey: Self.selectedTemplateKey) ?? ""
        selectedTemplate = LocalCLITemplate(rawValue: savedTemplateRaw) ?? .pi

        commandTemplate = UserDefaults.standard.string(forKey: Self.commandTemplateKey) ?? ""

        let savedTimeout = UserDefaults.standard.double(forKey: Self.timeoutSecondsKey)
        timeoutSeconds = savedTimeout > 0 ? savedTimeout : Self.defaultTimeoutSeconds
    }

    func loadTemplate(_ template: LocalCLITemplate) {
        selectedTemplate = template
        commandTemplate = template.commandTemplate
    }

    func enhance(systemPrompt: String, userPrompt: String) async throws -> String { throw OfflineMode.unavailable }
}
