import Foundation

/// Owns in-flight Apple Speech language installs so a download outlives the view that started it
/// and any view showing the same language can follow it.
///
/// Installs start only from an explicit user action (the Download button). The offline audit
/// confines references to this type to the language control for that reason.
@MainActor
final class NativeAppleSpeechAssetInstallCoordinator {
    static let shared = NativeAppleSpeechAssetInstallCoordinator()

    private var installs: [String: Task<NativeAppleSpeechAssetState, Never>] = [:]

    private init() {}

    func isInstalling(_ localeIdentifier: String) -> Bool {
        installs[Self.key(for: localeIdentifier)] != nil
    }

    /// Starts installing a language unless an install of it is already running.
    func begin(_ localeIdentifier: String) {
        _ = installTask(for: localeIdentifier)
    }

    /// Waits for the running install of a language, starting one if needed, and returns its outcome.
    /// Cancelling the caller stops the waiting, never the install.
    func install(_ localeIdentifier: String) async -> NativeAppleSpeechAssetState {
        await installTask(for: localeIdentifier).value
    }

    private func installTask(for localeIdentifier: String) -> Task<NativeAppleSpeechAssetState, Never> {
        let key = Self.key(for: localeIdentifier)
        if let running = installs[key] {
            return running
        }

        let task = Task {
            let result = await NativeAppleSpeechAssetManager.installAsset(for: localeIdentifier)
            self.installs[key] = nil
            return result
        }
        installs[key] = task
        return task
    }

    private static func key(for localeIdentifier: String) -> String {
        Locale(identifier: localeIdentifier).identifier(.bcp47)
    }
}
